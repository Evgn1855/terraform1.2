output "bastion_public_ip" {
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
  description = "Публичный IP бастиона для SSH подключения администраторов"
}

output "lbs"{
    value = {
        for listener in yandex_lb_network_load_balancer.balancer1.listener : listener.name => [
            for spec in listener.external_address_spec : spec.address
        ]
    }
}

output "web"{
  value = {
    for instance in yandex_compute_instance_group.my_group_balance.instances : instance.name => [
      instance.network_interface.0.ip_address
    ]
  }
}
output "zabbix_internal_ip" {
  description = "Внутренний (приватный) IP-адрес Zabbix-сервера для агентов"
  value       = yandex_compute_instance.zabbix.network_interface.0.ip_address
}

output "zabbix_ui_url" {
  value = "http://${yandex_compute_instance.zabbix.network_interface.0.nat_ip_address}:8080/zabbix"
}