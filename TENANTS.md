# Tenant allocations — dvntm

`tenant_index` is the single number a tenant is allocated. Everything else
derives from it, so this table is the only place a collision can happen.

Allocate the next free index, never reuse one while the tenant exists, and add
the row in the same change that adds the tenant directory.

| Index | Tenant | VRF VNI | VNet VNI(s) | Overlay subnet | Status |
|------:|--------|--------:|-------------|----------------|--------|
| 1 | `tdemo` | 10001 | 20010 | 10.20.129.0/24 | demo — destroy after verification |

## Derivation (ADR-0002)

For tenant index `n` on dvntm:

| Identifier | Formula | n = 1 |
|---|---|---|
| VRF VXLAN (the zone) | `10000 + n` | 10001 |
| VNet VNI, `i`th vnet | `20000 + n*10 + i` | 20010 |
| Overlay subnet | `10.20.{128+n}.0/24` | 10.20.129.0/24 |
| Anycast gateway | `.1` of that subnet | 10.20.129.1 |
| DHCP range | `.100` – `.200` | 10.20.129.100–200 |

dvnt uses the same formulas with bases 11000 / 21000 and `10.10.`.

Valid range is `n` = 1–63: the overlay block is `10.20.128.0/18`, and
`10.20.255.0/24` is reserved for fabric VTEP loopbacks.

## Naming constraint

PVE limits SDN zone and VNet IDs to **8 characters**, and the zone ID is the
tenant name verbatim. Pick names that fit; the module validates this rather
than letting the API reject it later.
