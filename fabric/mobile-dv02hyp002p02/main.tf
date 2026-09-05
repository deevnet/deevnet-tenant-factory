# The dvntm tenant fabric on hv02 - substrate-owned, built once.
#
# This is the fabric tenants land on, not a tenant itself. Per ADR-0001 it is a
# single-member EVPN fabric today and expands by adding members, not by being
# rebuilt: the objects below do not change shape when a second node joins, they
# just gain a neighbour.
#
# A note on structure that is easy to get wrong: in Proxmox a VRF *is* an EVPN
# zone - vrf_vxlan is a per-zone attribute. So ADR-0001's "one VRF per tenant"
# means one zone per tenant, and zones therefore belong to the tenant module,
# not here. What lives here is only what every tenant shares: the underlay
# fabric, this node's VTEP identity, and the EVPN control plane.
#
# The applier pattern is the provider's own idiom. SDN objects are staged and
# then applied as a unit; `finalizer` gives every resource something to depend
# on so staging happens before any apply, and the trailing applier commits.

resource "proxmox_sdn_applier" "finalizer" {}

# The underlay. OpenFabric rather than OSPF: it is the option PVE 9 added
# expressly to serve as an EVPN underlay, and it needs no area design.
resource "proxmox_sdn_fabric_openfabric" "tenant" {
  id        = var.fabric_id
  ip_prefix = var.loopback_prefix

  depends_on = [proxmox_sdn_applier.finalizer]
}

# This node's VTEP identity - ADR-0001 requirement #4. On a single-member
# fabric the loopback carries no inter-node traffic; it exists so the underlay
# is a real, code-defined thing from line one.
resource "proxmox_sdn_fabric_node_openfabric" "this" {
  fabric_id       = proxmox_sdn_fabric_openfabric.tenant.id
  node_id         = var.proxmox_node
  ip              = var.node_loopback
  interface_names = [var.underlay_interface]

  depends_on = [proxmox_sdn_applier.finalizer]
}

# The EVPN control plane. peers is left unset: with one member the fabric
# supplies the topology, and adding a node is what adds a neighbour.
resource "proxmox_sdn_controller_evpn" "tenant" {
  id     = "evpn1"
  asn    = var.asn
  fabric = proxmox_sdn_fabric_openfabric.tenant.id

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_applier" "fabric" {
  depends_on = [
    proxmox_sdn_fabric_openfabric.tenant,
    proxmox_sdn_fabric_node_openfabric.this,
    proxmox_sdn_controller_evpn.tenant,
  ]
}
