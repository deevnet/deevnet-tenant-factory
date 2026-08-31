variable "tenant_name" {
  type        = string
  description = <<-EOT
    Short tenant name. PVE limits SDN zone and vnet IDs to 8 characters, and
    the zone ID is this name verbatim, so it has to fit.
  EOT

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,7}$", var.tenant_name))
    error_message = "Tenant name must be 1-8 lowercase alphanumerics starting with a letter (PVE SDN zone ID limit)."
  }
}

variable "tenant_index" {
  type        = number
  description = <<-EOT
    The tenant's allocation number (ADR-0002). This single number fixes the
    VRF VNI, every VNet VNI, and the overlay subnet, so allocations cannot
    collide when the fabric gains members. Allocated once in TENANTS.md and
    never reused while the tenant exists.
  EOT
}

variable "controller_id" {
  type        = string
  description = "EVPN controller from the fabric stack."
}

variable "node" {
  type        = string
  description = "PVE node. Also the tenant's exit node - single-member fabric."
}

variable "site_octet" {
  type        = number
  description = "Second octet of the site block: 20 = dvntm, 10 = dvnt."
  default     = 20
}

variable "vrf_vni_base" {
  type        = number
  description = "Site base for VRF VNIs (ADR-0002): 10000 = dvntm, 11000 = dvnt."
  default     = 10000
}

variable "vnet_vni_base" {
  type        = number
  description = "Site base for VNet VNIs (ADR-0002): 20000 = dvntm, 21000 = dvnt."
  default     = 20000
}

variable "vnet_count" {
  type        = number
  description = "Number of VNets in this tenant's VRF."
  default     = 1
}

variable "dns_server" {
  type        = string
  description = <<-EOT
    Resolver advertised to tenant workloads by fabric DHCP. PVE requires this
    to be INSIDE the tenant subnet, so it defaults to the anycast gateway - the
    fabric's own dnsmasq, which forwards upstream. That is also the better
    shape: a tenant talks to its own gateway rather than reaching the core
    router directly, which is what ADR-0001 asks for.

    Override only with another address inside the tenant's own subnet.
  EOT
  default     = null
}

variable "vm_count" {
  type        = number
  description = "Workload VMs to clone from the template."
  default     = 1
}

variable "template_vm_id" {
  type        = number
  description = "VMID of the Packer-built Fedora template to clone."
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 2048
}

variable "datastore_id" {
  type        = string
  description = "Storage for clones and the cloud-init drive."
  default     = "local-lvm"
}

variable "ssh_keys" {
  type        = list(string)
  description = "Public keys injected by cloud-init."
  default     = []
}
