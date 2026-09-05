variable "proxmox_url" {
  type        = string
  description = "PVE API endpoint, e.g. https://10.20.99.22:8006/"
}

variable "proxmox_token_id" {
  type        = string
  description = "PVE API token ID, e.g. terraform-prov@pve!terraform-prov-token"
}

variable "proxmox_token_secret" {
  type        = string
  description = "PVE API token secret"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "PVE node name hosting this fabric"
  default     = "pve2"
}

# --- Numbering (ADR-0002) ----------------------------------------------------

variable "fabric_id" {
  type        = string
  description = "SDN fabric identifier. PVE limits this to 8 characters."
  default     = "tfab"

  validation {
    condition     = length(var.fabric_id) <= 8
    error_message = "PVE limits fabric IDs to 8 characters."
  }
}

variable "loopback_prefix" {
  type        = string
  description = "Prefix the fabric allocates VTEP loopbacks from."
  default     = "10.20.255.0/24"
}

variable "node_loopback" {
  type        = string
  description = "This node's VTEP identity. ADR-0001 requirement #4."
  default     = "10.20.255.2"
}

variable "underlay_interface" {
  type        = string
  description = <<-EOT
    Node interface the underlay runs over. Carries no traffic while the fabric
    has a single member; declared now so gaining a member is "add a neighbour"
    rather than "invent an underlay after the fact".
  EOT
  default     = "vmbr0.51"
}

variable "asn" {
  type        = number
  description = "BGP ASN for the EVPN control plane. Site-scoped: 65020 = dvntm."
  default     = 65020
}
