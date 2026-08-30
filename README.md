# Deevnet Tenant Factory

*Create tenant networks on the Proxmox network fabric.*

Terraform for the **tenant fabric** and the **tenants that land on it**, on the
dvntm tenant hypervisor.

The design is [ADR-0001: Tenant Network Fabric][adr1] and the numbering is
[ADR-0002][adr2], both in `deevnet-docs`, which is authoritative. This repo is
the implementation.

[adr1]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0001-tenant-network-fabric/
[adr2]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0002-tenant-fabric-numbering/

## Layout

```
fabric/dvntm-hv02/   the fabric itself - substrate-owned, built once
modules/tenant/      one tenant: VRF + VNet(s) + subnet + VMs
tenants/dvntm/       one directory per tenant instantiation
TENANTS.md           the tenant_index registry - allocate here first
```

## The structural point

In Proxmox **a VRF is an EVPN zone** — `vrf_vxlan` is a per-zone attribute. So
ADR-0001's "one VRF per tenant" means **one zone per tenant**, which is why
zones live in the tenant module and not in the fabric stack. The fabric holds
only what every tenant shares: the OpenFabric underlay, this node's VTEP
identity, and the EVPN controller.

## Usage

```bash
make fabric-init && make fabric-apply     # once, before any tenant

make tenant-init TENANT=tenants/dvntm/t-demo
make tenant-plan TENANT=tenants/dvntm/t-demo
make tenant-apply TENANT=tenants/dvntm/t-demo
```

### Adding a tenant

1. Allocate the next `tenant_index` in `TENANTS.md`.
2. Copy `tenants/dvntm/t-demo/` and set `tenant_name` and `tenant_index`.
3. `make tenant-apply TENANT=tenants/dvntm/<name>`

Names are capped at 8 characters — PVE's limit on SDN zone and VNet IDs, and
the zone ID is the tenant name verbatim. The module validates it rather than
letting the API reject it later.

## Credentials

None are stored here. The image factory already renders them out of the
inventory vault into a mode-0600 file, and every target sources it:

```bash
cd ../deevnet-image-factory && eval "$(make -s pve2-env)"
```

`make creds` does the same thing through this repo. This satisfies
`standards/secure-identity.md` §4.3 — IaC references secret locations, not
secret values.

## State

Local state, committed, per `architecture/tenant/building.md` ("VCS for small
deployments"). The fabric stack's outputs are read by tenants through
`terraform_remote_state`, so a tenant never hardcodes the controller or node.

## Scope

Terraform is **tenant-only** here, by doctrine. The substrate — VLANs, the
switch, the perimeter, and the hypervisor's own interfaces — is Ansible's, in
`ansible-collection-deevnet.net`. Terraform owns what lives inside the fabric.
