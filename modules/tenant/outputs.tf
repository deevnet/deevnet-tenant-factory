output "vrf_vni" {
  description = "VRF VXLAN ID for this tenant (ADR-0002)."
  value       = local.vrf_vni
}

output "subnet" {
  description = "Overlay subnet, served by fabric IPAM/DHCP."
  value       = local.subnet_cidr
}

output "gateway" {
  description = "Anycast gateway hosted by the fabric."
  value       = local.gateway
}

output "vnet_ids" {
  description = "VNet identifiers, which are also the bridge names on the node."
  value       = [for v in proxmox_sdn_vnet.this : v.id]
}

output "vm_names" {
  description = "Workload VM names."
  value       = proxmox_virtual_environment_vm.this[*].name
}
