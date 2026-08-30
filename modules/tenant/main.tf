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
resource "proxmox_sdn_subnet" "this" {
  vnet            = proxmox_sdn_vnet.this[0].id
  cidr            = local.subnet_cidr
  gateway         = local.gateway
  snat            = true
  dhcp_dns_server = var.dns_server

  dhcp_range = {
    start_address = "${local.subnet_base}.100"
    end_address   = "${local.subnet_base}.200"
  }

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

  network_device {
    bridge = proxmox_sdn_vnet.this[0].id
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
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
