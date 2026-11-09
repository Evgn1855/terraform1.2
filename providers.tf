terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.206.0"
    }
  
  
  
    local = {
      source = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  # token                    = "do not use!!!"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  service_account_key_file = file("~/.authorized_key.json")
}
