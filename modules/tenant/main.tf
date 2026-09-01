# One tenant: a VRF, its VNet(s), an addressed subnet, and workload VMs.
#
# In Proxmox a VRF *is* an EVPN zone - vrf_vxlan is a per-zone attribute - so
# ADR-0001's "one VRF per tenant" is realised as one zone per tenant. Tenants
# share the fabric and the EVPN controller; they share nothing else, and
# isolation between them is the VRF boundary rather than a firewall rule on the
# core router.
#
# Every identifier derives from tenant_index so a tenant cannot be given a
# number that collides with another once the fabric has more than one member
# (ADR-0001 build requirement #1).

locals {
  vrf_vni     = var.vrf_vni_base + var.tenant_index
  subnet_cidr = "10.${var.site_octet}.${128 + var.tenant_index}.0/24"
  subnet_base = "10.${var.site_octet}.${128 + var.tenant_index}"
  gateway     = "${local.subnet_base}.1"

  # Workload addresses. PVE cannot serve DHCP on an EVPN zone, so addresses are
  # derived rather than leased: .10 upwards, leaving .1 for the anycast gateway
  # and .2-.9 for future fabric use. Deterministic addressing also matches the
  # MAC-keyed, inventory-declared model the rest of this estate already uses.
  vm_addresses = [
    for i in range(var.vm_count) : "${local.subnet_base}.${10 + i}/24"
  ]

  vnet_ids = {
    for i in range(var.vnet_count) :
    i => format("%.6s%d", var.tenant_name, i)
  }
}

resource "proxmox_sdn_applier" "finalizer" {}

# The tenant's routing domain.
resource "proxmox_sdn_zone_evpn" "this" {
  id         = var.tenant_name
  controller = var.controller_id
  vrf_vxlan  = local.vrf_vni
  nodes      = [var.node]

  # Single-member fabric, so this node is also the way out. Tenant traffic
  # leaves here for the perimeter; per-tenant egress policy is not the core
  # router's job (ADR-0001 seam 1).
  exit_nodes        = [var.node]
  primary_exit_node = var.node

  # exit_nodes_local_routing is deliberately left at its default. It was tried
  # against the single-member egress problem and does nothing for it - it
  # governs reaching a VM's services FROM an exit node, not giving a VM a way
  # out. See ADR-0003.

  advertise_subnets = true
  ipam              = "pve"

  # VXLAN encapsulation overhead on a 1500-byte underlay.
  mtu = 1450

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_vnet" "this" {
  for_each = local.vnet_ids

  id   = each.value
  zone = proxmox_sdn_zone_evpn.this.id
  tag  = var.vnet_vni_base + (var.tenant_index * 10) + each.key

  depends_on = [proxmox_sdn_applier.finalizer]
}

# The tenant's address space, owned by the fabric rather than the core router.
# snat is what keeps the ADR's promise that the perimeter never learns tenant
# subnets: traffic is translated to the exit node's transit address on the way
# out, so the core router only ever sees the transit network.
#
# No dhcp_range here, and that is not an omission. PVE implements SDN DHCP in
# the *Simple* zone plugin only - EVPN, VLAN and VXLAN zones have no DHCP
# support at all in 9.2 (verified in PVE/Network/SDN/Zones/*Plugin.pm, and the
# API rejects the attribute outright: "unexpected property 'dhcp'"). So the
# subnet defines the tenant's address space and its anycast gateway, and
# addresses are handed to workloads by cloud-init instead of leased.
resource "proxmox_sdn_subnet" "this" {
  vnet    = proxmox_sdn_vnet.this[0].id
  cidr    = local.subnet_cidr
  gateway = local.gateway
  snat    = true

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_applier" "tenant" {
  depends_on = [
    proxmox_sdn_zone_evpn.this,
    proxmox_sdn_vnet.this,
    proxmox_sdn_subnet.this,
  ]
}

# Workloads. Addressing is DHCP from the fabric's own IPAM - the point of the
# design is that a tenant VM gets its address from the fabric, not from the
# core router.
resource "proxmox_virtual_environment_vm" "this" {
  count = var.vm_count

  name      = "${var.tenant_name}-${count.index + 1}"
  node_name = var.node
  tags      = ["tenant", var.tenant_name]

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  agent {
    enabled = true
  }

  # With the agent enabled the provider waits for the guest to report an IPv4
  # before it calls the create done. If the guest cannot get addressed - no
  # cloud-init in the template, say - that wait runs to the default timeout and
  # looks like a hang rather than a failure, while holding the state lock.
  # Ten minutes is generous for clone-and-boot and short enough to be a
  # diagnosis instead of an afternoon.
  timeout_create = 600

  network_device {
    bridge = proxmox_sdn_vnet.this[0].id
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = local.vm_addresses[count.index]
        gateway = local.gateway
      }
    }

    dns {
      servers = [var.dns_server != null ? var.dns_server : local.gateway]
    }

    dynamic "user_account" {
      for_each = length(var.ssh_keys) > 0 ? [1] : []
      content {
        username = "a_autoprov"
        keys     = var.ssh_keys
      }
    }
  }

  # The VNet has to exist as a bridge on the node before a VM can attach to it.
  depends_on = [proxmox_sdn_applier.tenant]
}

# --- DNS publication (ADR-0004) ----------------------------------------------
#
# The tenant authors its own names. The substrate created the zone and issued
# the TSIG key at onboarding, and does nothing further: adding a record here,
# rebuilding, or destroying the tenant never touches a substrate repository.
#
# These are RFC 2136 dynamic updates signed with the tenant's own key. The
# server accepts them for this tenant's zones and refuses them for anyone
# else's - the namespace boundary is enforced by PowerDNS, not by this module
# being well behaved.
#
# Not derived from Proxmox IPAM on purpose. PVE only writes a DNS record from
# its IPAM allocation paths, which this module does not use, and would give one
# A record per address with no way to name a service.

locals {
  dns_zone = "${var.tenant_name}.${var.dns_substrate}.${var.dns_root_domain}"

  # Reverse zone for the overlay /24, derived from tenant_index like everything
  # else: 10.20.129.0/24 -> 129.20.10.in-addr.arpa
  dns_reverse_zone = "${128 + var.tenant_index}.${var.site_octet}.10.in-addr.arpa"

  # Workload addresses are already deterministic, so the A records derive with
  # no new input: tdemo-1 -> 10.20.129.10, and so on.
  dns_workload_records = var.dns_publish ? {
    for i in range(var.vm_count) :
    "${var.tenant_name}-${i + 1}" => "${local.subnet_base}.${10 + i}"
  } : {}

  dns_extra = var.dns_publish ? var.dns_extra_records : {}
}

# One A record per workload.
resource "dns_a_record_set" "workload" {
  for_each = local.dns_workload_records

  zone      = "${local.dns_zone}."
  name      = each.key
  addresses = [each.value]
  ttl       = var.dns_ttl
}

# Tenant-authored service names: api, www, whatever the tenant needs.
resource "dns_a_record_set" "extra" {
  for_each = local.dns_extra

  zone      = "${local.dns_zone}."
  name      = each.key
  addresses = [each.value]
  ttl       = var.dns_ttl
}

# Reverse records. Cheap, because the reverse zone is delegated per tenant
# alongside the forward one and the addressing is deterministic.
resource "dns_ptr_record" "workload" {
  for_each = local.dns_workload_records

  zone = "${local.dns_reverse_zone}."
  name = split(".", each.value)[3]
  ptr  = "${each.key}.${local.dns_zone}."
  ttl  = var.dns_ttl
}
