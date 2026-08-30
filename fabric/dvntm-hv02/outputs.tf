# Consumed by tenant instantiations - a tenant needs to know which controller
# and node to attach its VRF to, and should not hardcode either.

output "controller_id" {
  description = "EVPN controller every tenant zone attaches to."
  value       = proxmox_sdn_controller_evpn.tenant.id
}

output "fabric_id" {
  description = "Underlay fabric identifier."
  value       = proxmox_sdn_fabric_openfabric.tenant.id
}

output "node" {
  description = "PVE node hosting this fabric; tenants use it as their exit node."
  value       = var.proxmox_node
}

output "vtep_loopback" {
  description = "This member's VTEP address."
  value       = proxmox_sdn_fabric_node_openfabric.this.ip
}
