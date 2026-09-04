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
  default     = 100
}

variable "ssh_keys" {
  type        = list(string)
  description = "Public keys injected by cloud-init."
  default     = []
}

# --- DNS publication (ADR-0004) ----------------------------------------------

variable "tsig_key_name" {
  type        = string
  description = <<-EOT
    Name of this tenant's TSIG key. The substrate issued it at onboarding and
    bound it to this tenant's zones with TSIG-ALLOW-DNSUPDATE, so it is accepted
    for those zones and refused for every other tenant's. By convention it is
    the tenant name.
  EOT
  default     = "tdemo"
}

variable "tsig_key_secret" {
  type        = string
  sensitive   = true
  description = <<-EOT
    The shared secret for tsig_key_name, from the substrate vault
    (vault_tenant_tsig_keys). Never commit it: pass it as TF_VAR_tsig_key_secret
    like the Proxmox credentials, which is why there is no default.
  EOT
}

variable "dns_update_server" {
  type        = string
  description = <<-EOT
    Authoritative server that accepts the dynamic updates. This is the tenant
    DNS host, not the substrate resolver: workloads still *resolve* through
    10.20.99.1, which delegates these zones here.
  EOT
  default     = "10.20.99.30"
}
