variable "proxmox_url" {
  type = string
}

variable "proxmox_token_id" {
  type = string
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

variable "template_vm_id" {
  type        = number
  description = "VMID of the Fedora template to clone."
  default     = 100
}

variable "ssh_keys" {
  type        = list(string)
  description = "Public keys injected by cloud-init."
  default     = []
}
