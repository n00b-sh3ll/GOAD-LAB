variable "pm_api_url" {
  default = "https://192.168.150.200:8006/api2/json"
}

variable "pm_user" {
  default = "infra_as_code@pve"
}

variable "pm_password" {
  default = "delta@123"
}

variable "pm_node" {
  default = "pve"
}

variable "pm_pool" {
  default = "GOAD"
}

variable "pm_full_clone" {
  default = false
}

# change this value with the id of your templates (win10 can be ignored if not used)
variable "vm_template_id" {
  type = map(number)

  # set the ids according to your templates
  default = {
      "WinServer2019x64-cloudinit"  = 0
      "WinServer2016x64-cloudinit"  = 0
      "Windows10_22h2_x64" = 0
  }
}

variable "storage" {
  # change this with the name of the storage you use
  default = "Data"
}

variable "network_bridge" {
  default = "vmbr0"
}

variable "network_model" {
  default = "e1000"
}

variable "network_vlan" {
  default = 10
}


"dc01" = {
  name               = "DC01"
  desc               = "DC01 - windows server 2019 - {{ip_range}}.10"
  cores              = 2
  memory             = 3096
  clone              = "WinServer2019x64-cloudinit"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.10/24"
  gateway            = "{{ip_range}}.1"
}
"dc02" = {
  name               = "DC02"
  desc               = "DC02 - windows server 2019 - {{ip_range}}.11"
  cores              = 2
  memory             = 3096
  clone              = "WinServer2019x64-cloudinit"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.11/24"
  gateway            = "{{ip_range}}.1"
}
"dc03" = {
  name               = "DC03"
  desc               = "DC03 - windows server 2016 - {{ip_range}}.12"
  cores              = 2
  memory             = 3096
  clone              = "WinServer2016x64-cloudinit"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.12/24"
  gateway            = "{{ip_range}}.1"
}
"srv02" = {
  name               = "SRV02"
  desc               = "SRV02 - windows server 2019 - {{ip_range}}.22"
  cores              = 2
  memory             = 6240
  clone              = "WinServer2019x64-cloudinit"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.22/24"
  gateway            = "{{ip_range}}.1"
}
"srv03" = {
  name               = "SRV03"
  desc               = "SRV03 - windows server 2016 - {{ip_range}}.23"
  cores              = 2
  memory             = 5120
  clone              = "WinServer2016x64-cloudinit"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.23/24"
  gateway            = "{{ip_range}}.1"
}
