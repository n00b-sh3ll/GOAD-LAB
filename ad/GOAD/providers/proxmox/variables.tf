variable "pm_api_url" {
  description = "Proxmox API URL"
  default     = "https://192.168.150.200:8006/api2/json"
}

variable "pm_user" {
  description = "Proxmox API user"
  default     = "infra_as_code@pve"
}

variable "pm_password" {
  description = "Proxmox API password"
  sensitive   = true
  default     = "delta@123"
}

variable "pm_node" {
  description = "Proxmox node name"
  default     = "pve"
}

variable "pm_pool" {
  description = "Proxmox resource pool"
  default     = "GOAD"
}

variable "pm_full_clone" {
  description = "Use full clone instead of linked clone"
  default     = false
}

variable "ip_range" {
  description = "IP prefix for all VMs (ex: 192.168.150)"
  default     = "10.10.0"
}

variable "vm_template_id" {
  description = "Map of template names to Proxmox VM IDs"
  type        = map(number)
  default = {
    "WinServer2019x64-cloudinit" = 0
    "WinServer2016x64-cloudinit" = 0
    "Windows10_22h2_x64"         = 0
  }
}

variable "storage" {
  description = "Proxmox storage pool name"
  default     = "Data"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "network_model" {
  description = "VM network adapter model"
  default     = "e1000"
}

variable "network_vlan" {
  description = "VLAN tag for VM network"
  default     = 10
}
