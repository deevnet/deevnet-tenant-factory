# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Terraform for the tenant EVPN fabric on the dvntm tenant hypervisor (hv02,
node `pve2`), and for the tenants that land on it.

`deevnet-docs` is authoritative. ADR-0001 defines the fabric model and ADR-0002
the numbering. If this repo disagrees with those, the ADRs win.

## Rules that are easy to get wrong

- **Tenants do not live in this repository.** Each tenant is its own repo,
  `deevnet-tenant-<name>` (ADR-0006). What lives here is the substrate half:
  the fabric, the module, the registry, the reference implementation.
- **`examples/tenant/` is never applied.** It ships with `tenant_index = 0`,
  which the module rejects, so an unedited copy cannot be applied. Do not
  "fix" that by giving it a valid index - the invalidity is the guard.
- **Never move a module tag.** Tenants pin `?ref=tenant-module-vX.Y.Z`, and a
  moved tag silently changes what an already-applied tenant is running.

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
  rendered env file. Never add a `*.tfvars` holding a token. That includes the
  TSIG secret: pass it as `TF_VAR_tsig_key_secret`, sourced from the substrate
  vault (`vault_tenant_tsig_keys`).
- **DNS records are tenant content (ADR-0004).** A tenant publishes into its own
  delegated zone `<tenant>.<site>.deevnet.net` over RFC 2136, signed with a TSIG
  key the substrate issued and bound to that tenant's zones. Workload A and PTR
  records derive from the addressing; `dns_extra_records` is where a tenant adds
  service names. Do **not** reach for Proxmox's SDN DNS integration: it only
  writes a record from the IPAM allocation paths, which this module does not
  use, so it would publish nothing.

## Commands

```bash
make fabric-plan / fabric-apply
make fabric-contract                 # issued attachment vs the fabric's outputs
make tenant-attachment TENANT=<path> # issue a tenant its controller_id / node
make validate                        # fabric, module, and the example
make example-plan                    # live plan of the example, creates nothing
make fmt
```

## Verification that actually matters

A tenant is correct when its VM carries the address cloud-init gave it (there
is no fabric DHCP — Proxmox implements SDN DHCP for *Simple* zones only),
reaches its anycast gateway, egresses with the core router seeing only the
transit address, and cannot reach another tenant's subnet.

Verify egress **from inside the workload**, not from the exit node's SNAT
counter. A climbing counter only proves packets left; it was the basis of the
ADR-0003 misdiagnosis, where requests egressed and were answered while the
replies were dropped on the way back in. `ping` and `curl` in the VM are the
test.

Egress also has to leave the *right way*. `ip route get <mgmt-address> vrf
vrf_<tenant>` on the node must resolve via the transit interface. If it
resolves via the management bridge, the VRF is falling through to the node's
main routing table and tenant traffic is reaching the management segment
without passing the perimeter.
