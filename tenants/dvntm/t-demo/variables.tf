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
  description = <<-EOT
    VMID of the Fedora template to clone. Note this changes every time the
    image factory rebuilds the template - Proxmox assigns the next free ID
    rather than reusing one - so it is a variable rather than a constant, and
    it needs updating after a rebuild.
  EOT
  default     = 103
}

variable "ssh_keys" {
  type        = list(string)
  description = "Public keys injected by cloud-init."
  default     = []
}
