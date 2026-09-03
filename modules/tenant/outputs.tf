output "vrf_vni" {
  description = "VRF VXLAN ID for this tenant (ADR-0002)."
  value       = local.vrf_vni
}

output "subnet" {
  description = "Overlay subnet. Registered in fabric IPAM; workloads are addressed by cloud-init."
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

output "dns_zone" {
  description = "The tenant's delegated forward zone (ADR-0004)."
  value       = local.dns_zone
}

output "dns_reverse_zone" {
  description = "The tenant's delegated reverse zone."
  value       = local.dns_reverse_zone
}

output "dns_names" {
  description = "Fully qualified names this tenant publishes."
  value = var.dns_publish ? sort(concat(
    [for n, _ in local.dns_workload_records : "${n}.${local.dns_zone}"],
    [for n, _ in local.dns_extra : "${n}.${local.dns_zone}"],
  )) : []
}
