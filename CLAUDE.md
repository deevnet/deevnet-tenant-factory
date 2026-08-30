# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Terraform for the tenant EVPN fabric on the dvntm tenant hypervisor (hv02,
node `pve2`), and for the tenants that land on it.

`deevnet-docs` is authoritative. ADR-0001 defines the fabric model and ADR-0002
the numbering. If this repo disagrees with those, the ADRs win.

## Rules that are easy to get wrong

- **A VRF is an EVPN zone.** `vrf_vxlan` is per-zone, so "one VRF per tenant"
  means one `proxmox_sdn_zone_evpn` per tenant. Zones belong to the tenant
  module; the fabric stack holds only the shared underlay, VTEP identity, and
  EVPN controller.
- **Numbering derives from `tenant_index`.** Never hand-assign a VNI or a
  subnet. Allocate the index in `TENANTS.md` and let the module derive the
  rest — that is ADR-0001 build requirement #1, which is what keeps the door
  open to a multi-member fabric.
- **8 characters** is the PVE limit on SDN zone and VNet IDs.
- **Use the short-form `proxmox_sdn_*` resources.** The
  `proxmox_virtual_environment_sdn_*` forms are deprecated and are removed at
  provider v1.0.
- **`proxmox_sdn_applier`** is the provider's staging idiom: SDN objects are
  staged and applied as a unit. Every SDN resource depends on a `finalizer`
  applier, and a trailing applier commits.
- **Terraform is tenant-only.** The substrate — VLANs, switch, perimeter,
  hypervisor interfaces — is Ansible's, in `ansible-collection-deevnet.net`
  (see the `proxmox_node_network` role). Do not reach into it from here.
- **No secrets in this repo.** Credentials come from the image factory's
  rendered env file. Never add a `*.tfvars` holding a token.

## Commands

```bash
make fabric-plan / fabric-apply
make tenant-plan TENANT=tenants/dvntm/<name>
make validate      # every stack
make fmt
```

## Verification that actually matters

A tenant is correct when its VM takes an address from **fabric** DHCP (not
OPNsense Kea), reaches its anycast gateway, egresses with the core router
seeing only the transit address, and cannot reach another tenant's subnet.
