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
examples/tenant/     the reference implementation - copied OUT, never applied
TENANTS.md           the tenant_index registry - allocate here first
```

## The structural point

In Proxmox **a VRF is an EVPN zone** — `vrf_vxlan` is a per-zone attribute. So
ADR-0001's "one VRF per tenant" means **one zone per tenant**, which is why
zones live in the tenant module and not in the fabric stack. The fabric holds
only what every tenant shares: the OpenFabric underlay, this node's VTEP
identity, and the EVPN controller.

## Usage

**Tenants do not live here.** Each tenant is its own repository,
`deevnet-tenant-<name>` (ADR-0006), and applies itself. What lives here is the
substrate half: the fabric, the module every tenant consumes, the registry, and
the reference implementation.

```bash
make fabric-init && make fabric-apply     # once, before any tenant
make fabric-contract                      # issued attachment still matches the fabric?
make validate                             # fabric, module, and the example
make example-plan                         # live plan of the example, creates nothing
```

### Adding a tenant

1. Allocate the next `tenant_index` in `TENANTS.md`.
2. `cp -r examples/tenant/. ../deevnet-tenant-<name>/` and replace every
   `REPLACE-ME`.
3. Issue what the substrate owes it — all driven from the tenant registry in
   `ansible-inventory-deevnet`:
   - `make tenant-attachment TENANT=../deevnet-tenant-<name>`
   - TSIG key and DNS zone (`deevnet.mgmt --tags tenant-dns`), delegation
     (`deevnet.net playbooks/dns.yml`), egress (ADR-0003), and a state
     credential if the tenant wants the store
4. `make init && make apply` **in the tenant's own repository**.

From then on the tenant's lifecycle touches nothing here. The `tenant-*` targets
in this repo still exist for pointing at a tenant repo explicitly
(`TENANT=../deevnet-tenant-<name>`), and refuse to run without one.

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

**The fabric's** state is committed here. Five substrate-owned resources, one
operator, and a repository is a good home for that: a clone gives you code and
state together, and history gives you every prior state with no restore path to
rehearse.

**Tenants'** state is not here, because tenants are not here. It lives in the
substrate's state store or wherever a tenant chooses to carry it — the store is
offered, not mandated (ADR-0007).

## The fabric attachment

Tenants no longer read `controller_id` and `node` out of the fabric's state:
they cannot, from another repository. The substrate **issues** them at
onboarding, beside the TSIG key and the egress, from the tenant registry in
`ansible-inventory-deevnet`.

A tenant never *invents* them. `fabric/dvntm-hv02/outputs.tf` remains the source
of truth, and `make fabric-contract` diffs what was issued against it.

## Scope

Terraform is **tenant-only** here, by doctrine. The substrate — VLANs, the
switch, the perimeter, and the hypervisor's own interfaces — is Ansible's, in
`ansible-collection-deevnet.net`. Terraform owns what lives inside the fabric.
