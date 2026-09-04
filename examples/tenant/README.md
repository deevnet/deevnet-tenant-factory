# Reference tenant

**This directory is an example. It cannot be applied, and that is enforced
rather than requested** — `tenant_index = 0` is outside ADR-0002's valid range,
so `terraform plan` fails at variable validation with a message telling you what
to do instead.

Copy it into its own repository to create a real tenant:

```bash
cp -r examples/tenant/. ../deevnet-tenant-<name>/
```

Then, in the new repository, replace every `REPLACE-ME`:

| Where | With |
|---|---|
| `main.tf` — `tenant_name` | your tenant name |
| `main.tf` — `tenant_index` | the index you allocated in `TENANTS.md` |
| `main.tf` — backend `key` | `tenants/<name>/terraform.tfstate` |
| `variables.tf` — `tsig_key_name` default | your tenant name |
| `Makefile` — the vault path in `require-secret` | your tenant name |

## Onboarding, in order

Onboarding is a substrate act, done once ([ADR-0004](https://github.com/deevnet/deevnet-docs) §5).
Everything after it is yours.

1. **Allocate an index** in the factory's `TENANTS.md`.
2. **Create the repository** from this example.
3. **Have the substrate issue what it owes you** — all driven from the tenant
   registry in `ansible-inventory-deevnet`:
   - the fabric attachment: `make tenant-attachment TENANT=../deevnet-tenant-<name>`
   - a TSIG key and a DNS zone (`deevnet.mgmt`, `--tags tenant-dns`)
   - the Unbound delegation (`deevnet.net`, `playbooks/dns.yml`)
   - egress ([ADR-0003](https://github.com/deevnet/deevnet-docs))
   - a state credential, if you want the state store
4. **`make init && make plan && make apply`** in your own repository.

From then on, adding a record, rebuilding and destroying are `terraform apply`
and touch no substrate repository.

## Declining the state store

The state store is offered, not mandated
([ADR-0007](https://github.com/deevnet/deevnet-docs)). To carry your own custody,
delete the `backend "s3"` block from `main.tf` and remove `terraform.tfstate`
from `.gitignore` — or keep state local and uncommitted, and back it up yourself.

You then own the consequence: state is not disposable, because losing it means
Terraform can no longer manage or destroy what it created.
