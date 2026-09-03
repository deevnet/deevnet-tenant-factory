# Tenant allocations — dvntm

`tenant_index` is the single number a tenant is allocated. Everything else
derives from it, so this table is the only place a collision can happen.

Allocate the next free index, never reuse one while the tenant exists, and add
the row in the same change that adds the tenant directory.

| Index | Tenant | VRF VNI | VNet VNI(s) | Overlay subnet | DNS zone | Status |
|------:|--------|--------:|-------------|----------------|----------|--------|
| 1 | `tdemo` | 10001 | 20010 | 10.20.129.0/24 | `tdemo.dvntm.deevnet.net` | demo — destroy after verification |

## Derivation (ADR-0002)

For tenant index `n` on dvntm:

| Identifier | Formula | n = 1 |
|---|---|---|
| VRF VXLAN (the zone) | `10000 + n` | 10001 |
| VNet VNI, `i`th vnet | `20000 + n*10 + i` | 20010 |
| Overlay subnet | `10.20.{128+n}.0/24` | 10.20.129.0/24 |
| Anycast gateway | `.1` of that subnet | 10.20.129.1 |
| Workload addresses | `.10` upward, by index | 10.20.129.10, .11, … |
| Forward DNS zone | `<tenant>.<site>.deevnet.net` | `tdemo.dvntm.deevnet.net` |
| Reverse DNS zone | `{128+n}.{site octet}.10.in-addr.arpa` | `129.20.10.in-addr.arpa` |

dvnt uses the same formulas with bases 11000 / 21000 and `10.10.`.

There is **no DHCP range**. Proxmox implements SDN DHCP in the *Simple* zone
plugin only; EVPN zones have none, and the API rejects the attribute. Workloads
are addressed by cloud-init from `.10` upward, derived from the index rather
than leased (ADR-0002 as amended 2026-09-01). `.2`–`.9` stay reserved.

Valid range is `n` = 1–63: the overlay block is `10.20.128.0/18`, and
`10.20.255.0/24` is reserved for fabric VTEP loopbacks.

## Onboarding a tenant

Allocating a row here is the tenant's own act. Two substrate steps go with it,
both driven from `deevnet_tenants` in the inventory (`group_vars/all/tenants.yml`)
and both done once:

1. **Egress** (ADR-0003) — the tenant VRF gets a way out.
2. **DNS** (ADR-0004) — its forward and reverse zones are created on the tenant
   DNS server and a TSIG key is issued and bound to them, and the core router's
   Unbound is given the matching delegation.

Everything after that — adding records, rebuilding, destroying — is the tenant's
own `terraform apply` and touches no substrate repository.

## Naming constraint

PVE limits SDN zone and VNet IDs to **8 characters**, and the zone ID is the
tenant name verbatim. Pick names that fit; the module validates this rather
than letting the API reject it later.
