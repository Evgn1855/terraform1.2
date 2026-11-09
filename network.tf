#создаем облачную сеть
resource "yandex_vpc_network" "my_network" {
  name = "my_network_${var.flow}"
}

#Доступные зоны yc compute zone list
#создаем подсеть zone E - это описание подсети
resource "yandex_vpc_subnet" "subnet_e" {
  name           = "my_network_${var.flow}-ru-central1-e"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#создаем подсеть zone D - это описание подсети
resource "yandex_vpc_subnet" "subnet_d" {
  name           = "my_network_${var.flow}-ru-central1-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

# ДОБАВЛЯЕМ: Новая подсеть специально под хост Zabbix
resource "yandex_vpc_subnet" "subnet_zabbix" {
  name           = "my_network_${var.flow}-zabbix-ru-central1-e"
  zone           = "ru-central1-e" # Зона должна совпадать с зоной ВМ Zabbix
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = ["10.0.3.0/24"] # Новый непересекающийся диапазон
  
  # КРИТИЧЕСКИ ВАЖНО: Строку route_table_id здесь НЕ ПИШЕМ!
}


#создаем NAT для выхода в интернет
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "fops-gateway-${var.flow}"
  shared_egress_gateway {}
}

#создаем сетевой маршрут для выхода в интернет через NAT
resource "yandex_vpc_route_table" "rt" {
  name       = "fops-route-table-${var.flow}"
  network_id = yandex_vpc_network.my_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#создаем группы безопасности(firewall)
# 1. Группа безопасности для Бастиона 
resource "yandex_vpc_security_group" "bastion" {
  name       = "bastion-sg-${var.flow}"
  network_id = yandex_vpc_network.my_network.id
  ingress { #Вход
    description    = "Allow SSH from anywhere to Bastion. Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  egress { #Выход
    description    = "Permit ANY" #Разрешить все
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0#от
    to_port        = 65535#до
  }

}

# 2. ВНУТРЕННЯЯ СЕТЬ LAN (Бастион + Веб-сервера+Zabbix внешний выход)
resource "yandex_vpc_security_group" "LAN" { #Группа безопасности LAN
  name       = "LAN-sg-${var.flow}"
  network_id = yandex_vpc_network.my_network.id
  ingress {#Вход
    description    = "Allow 10.0.0.0/8"
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/8"]
    from_port      = 0#от
    to_port        = 65535#до
  }
  
  egress {#выход
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0 #от
    to_port        = 65535 #до
  }
}
#ОТДЕЛЬНАЯ ТОЧЕЧНАЯ ГРУППА ДЛЯ ZABBIX SERVER (Только для самого хоста Zabbix)
resource "yandex_vpc_security_group" "zabbix_server_sg" {
  name       = "zabbix-server-external-sg"
  network_id = yandex_vpc_network.my_network.id

  # Порт 8080 открывается ТОЛЬКО для этой группы безопасности
  ingress {
    protocol       = "TCP"
    description    = "Allow Zabbix Web UI from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8080
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
# 3. ВЕБ-ПЕРИМЕТР (Балансировщик + Веб-сервера)
# Группа безопасности для веб-серверов (разрешен трафик от балансировщика и бастиона)
resource "yandex_vpc_security_group" "web_sg" { #Группа безопасности web_sg
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.my_network.id


  ingress {#Вход
    description    = "Allow HTTPS traffic"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {#Вход
    description    = "Allow HTTP traffic"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  #Для доступа к веб серверам через балансировщик, а так же для проверки статуса серверов балансировщиком 
  
  
  ingress {#Вход
    protocol          = "TCP"
    description       = "Health checks from Load Balancer"
    predefined_target = "loadbalancer_healthchecks"
    port              = 80
  }
  #?
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

}
