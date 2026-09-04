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

  # The range is ADR-0002's own: the site /18 holds 63 tenants. Index 0 is
  # excluded and carries a second job - it marks the reference implementation in
  # examples/, so that example CANNOT be applied rather than merely asking not to
  # be. A guard rail that depends on being read is not a guard rail.
  validation {
    condition     = var.tenant_index >= 1 && var.tenant_index <= 63
    error_message = <<-EOT
      tenant_index must be 1-63 (ADR-0002: the site /18 holds 63 tenants).

      Index 0 marks the reference implementation and is deliberately invalid.
      To create a tenant, copy examples/tenant/ into its own repository and
      allocate a real index in TENANTS.md:

        cp -r examples/tenant/. ../deevnet-tenant-<name>/
    EOT
  }
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
    Resolver handed to tenant workloads via cloud-init. Defaults to the
    substrate resolver on the core router: with no DHCP on an EVPN zone there
    is no dnsmasq on the anycast gateway, so nothing would answer there.

    Reaching it reaches the perimeter, which is allowed - the tenant->platform
    path exists for exactly this kind of shared service.
  EOT
  default     = "10.20.99.1"
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

# --- DNS publication (ADR-0004) ----------------------------------------------

variable "dns_publish" {
  type        = bool
  description = <<-EOT
    Publish this tenant's names into its delegated zone. The substrate creates
    the zone and issues the TSIG key at onboarding; everything after that -
    records, rebuilds, destroys - is this module's job and touches no substrate
    repository.
  EOT
  default     = true
}

variable "dns_substrate" {
  type        = string
  description = "Site label in the zone name: dvntm or dvnt."
  default     = "dvntm"
}

variable "dns_root_domain" {
  type        = string
  description = "Root domain the site zone hangs off."
  default     = "deevnet.net"
}

variable "dns_ttl" {
  type        = number
  description = "TTL for published records."
  default     = 300
}

variable "dns_extra_records" {
  type        = map(string)
  description = <<-EOT
    Tenant-authored names beyond the per-workload A records, as
    name -> IPv4 address. Keys are relative to the tenant zone, so
    "api" becomes api.<tenant>.<site>.deevnet.net.

    This is the half of the tenant contract that the Proxmox IPAM hook could
    never have provided: it registers one address at allocation time and has no
    concept of a service name.
  EOT
  default     = {}
}
