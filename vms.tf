#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# Zabbix хост (Создается первым, так как его IP нужен в конфигах агентов)
resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-e" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores  = 2
    memory = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_zabbix.id  # отдельная подсеть для Zabbix
    nat                = true #если указано, то есть внешний IP
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.zabbix_server_sg.id]
  }

  metadata = {
      user-data          = file("./cloud-init-zabbix-server.yml")
      serial-port-enable = 1
  }
}

#Бастион
resource "yandex_compute_instance" "bastion" {
  name        = "bastion" #Имя ВМ в облачной консоли
  hostname    = "bastion" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-e" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }


  metadata = {
      user-data          = file("./cloud-init-bastion.yml")
      serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_e.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true #если указано, то есть внешний IP
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}



#Создание хостов через группу

#В Yandex Cloud при использовании ресурса yandex_compute_instance_group имена создаваемых виртуальных машин формируются автоматически на основе базового имени группы с добавлением случайного буквенно-цифрового суффикса.
resource "yandex_compute_instance_group" "my_group_balance" { #описание группы ВМ
  name                = "fixed-ig-with-balancer"
  folder_id           = var.folder_id
  service_account_id  = "ajepfi4o7mfpkssmr98n"
  deletion_protection = false
  
  instance_template {
    platform_id = "standard-v3"
    resources {
      memory = 2
      cores  = 2
      core_fraction = 20
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
        type     = "network-hdd"
        size     = 10
      }
    }

    network_interface {
      network_id         = yandex_vpc_network.my_network.id
      #subnet_ids         = ["${yandex_vpc_subnet.subnet-1.id}"]
      subnet_ids         = [ yandex_vpc_subnet.subnet_e.id, yandex_vpc_subnet.subnet_d.id]#Подсети для каждой машины?
      nat                = false #если указано, то есть внешний IP 
      security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id] #группы безопасности прописаны в network.tf
    }

    metadata = {
      user-data          = file("./cloud-init-web-servers.yml")
      serial-port-enable = 1
    }
  

  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-e","ru-central1-d"]
  }

  deploy_policy {
    max_unavailable = 1 #Во время обновления одновременно может быть недоступна максимум 1 ВМ.
    max_expansion   = 0 #Группе запрещено временно расширяться выше целевого размера во время обновления
  }

  load_balancer {
    target_group_name        = "group-for-balansed" 
    target_group_description = "Целевая группа Network Load Balancer"
  }
}  


resource "yandex_lb_network_load_balancer" "balancer1" { #балансировщик нагрузки
  name = "network-load-balancer-1"
  deletion_protection = "false"
  
  listener {
    name = "network-load-balancer-1-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    #target_group_id = yandex_compute_instance_group.my_group_balance.id #описание группы ВМ + название группы
    # Ссылаемся на ID целевой группы, которую автоматически создала группа ВМ выше
    target_group_id = yandex_compute_instance_group.my_group_balance.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/index.html"
      }
    }
  }
}


resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}
  [Zabbix external]
  ${yandex_compute_instance.zabbix.network_interface.0.nat_ip_address}
  [Zabbix internal]
  ${yandex_compute_instance.zabbix.network_interface.0.ip_address}
  [balancer]
  %{ for l in yandex_lb_network_load_balancer.balancer1.listener ~}
  %{ for spec in l.external_address_spec ~}
  ${spec.address}
  %{ endfor ~}
  %{ endfor ~}
  [webservers]
  %{ for instance in yandex_compute_instance_group.my_group_balance.instances ~}
  ${instance.network_interface.0.ip_address}
  %{ endfor ~}
  
  [webservers:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  XYZ
  filename = "./hosts.ini"
}
