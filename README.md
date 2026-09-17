# Deevnet Tenant Fabric

*The EVPN fabric that makes a hypervisor ready for tenants.*

Terraform for the **tenant fabric** on the mobile tenant hypervisor: the
OpenFabric underlay, the node's VTEP identity, and the EVPN controller every
tenant's zone attaches to.

The design is [ADR-0001: Tenant Network Fabric][adr1] and the numbering is
[ADR-0002][adr2], both in `deevnet-docs`, which is authoritative.

[adr1]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0001-tenant-network-fabric/
[adr2]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0002-tenant-fabric-numbering/
[adr15]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0015-tenant-onboarding-through-api/

## Tenants are not built here

[ADR-0015][adr15] moved every per-tenant object behind the Deevnet API: a
tenant's zone, VNets, subnet, workloads and names are created by the API and
declared in the tenant's own Terraform through the `deevnet/deevnet` provider.
So a tenant holds no Proxmox credential, and this repository holds no tenant.

What used to live here and where it went:

| Was here | Now |
|---|---|
| `modules/tenant` | the API builds the tenant network and workloads (ADR-0015 §11, §12) |
| `examples/tenant` | `deevnet-tenant-tdemo`, the reference tenant (ADR-0015 §9) |
| `TENANTS.md` | the API's registry is the only one (ADR-0015 §1) |
| `make tenant-attachment` | `create tenant` returns the attachment |

The tags `tenant-module-vX.Y.Z` stay: they are what the tenants built before the
cutover were applied from.

## Layout

```
fabric/mobile-dv02hyp002p02/   the fabric - substrate-owned, built once
```

## The structural point

In Proxmox **a VRF is an EVPN zone**: `vrf_vxlan` is a per-zone attribute. So
ADR-0001's "one VRF per tenant" means one zone per tenant, and those zones are
the API's to build. The fabric holds only what every tenant shares.

## Usage

```bash
make fabric-init && make fabric-apply     # once, before any tenant
make validate                             # fmt check + validate
```

Credentials are never stored here: the image factory renders them from the
inventory vault, and every target sources that file.
