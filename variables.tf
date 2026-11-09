variable "flow" {
  type    = string
  default = "24-01"
}


#cloud_id и folder_id можно посмотреть из команды yc config list (нужно авторизоваться яндекс облаке, подтверждение через браузер)
variable "cloud_id" {
  type    = string
  default = "b1g1ad0p8vm26m7t3n12"
}
variable "folder_id" {
  type    = string
  default = "b1g4s2ti1evo8s936cp3"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
}
