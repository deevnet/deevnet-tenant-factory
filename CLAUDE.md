# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Terraform for the tenant EVPN fabric on the mobile tenant hypervisor (hv02,
node `dv02hyp002p02`): the OpenFabric underlay, this node's VTEP identity, and
the EVPN controller.

`deevnet-docs` is authoritative. ADR-0001 defines the fabric model, ADR-0002 the
numbering, and ADR-0015 moved every per-tenant object behind the Deevnet API. If
this repo disagrees with those, the ADRs win.

## Rules that are easy to get wrong

- **Tenants are not built here** (ADR-0015). The API builds a tenant's zone,
  VNets, subnet, workloads and names; a tenant declares them in its own
  repository through the `deevnet/deevnet` provider. Don't add a tenant module,
  an example tenant or an index registry back into this repo.
- **A VRF is an EVPN zone.** `vrf_vxlan` is per-zone, so "one VRF per tenant"
  means one zone per tenant. Those zones are the API's; this stack holds only
  the shared underlay, VTEP identity and EVPN controller.
- **Never move a `tenant-module-vX.Y.Z` tag.** The module is gone from `main`,
  but the tags stay: they are what tenants applied from before the cutover.
- **Numbering derives from the tenant index** (ADR-0002). Nothing here assigns
  a VNI or a subnet by hand, and neither does the API.
- **An SDN apply is cluster-wide.** The API serialises its own applies; don't
  run `fabric-apply` while a tenant is being built.
- **Credentials are never stored here.** The image factory renders them from the
  inventory vault, and every target sources that file.
