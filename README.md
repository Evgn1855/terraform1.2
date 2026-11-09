yandex_vpc_address  для статического IP,  привязывают к интерфейсу
subnet_id = yandex_vpc_subnet.subnet_d.id   # только указывает подсеть
nat       = true                            # вот это даёт внешний IP
