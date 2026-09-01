# Without this, Terraform infers hashicorp/proxmox for the proxmox_* resources
# and fails to find a provider.
terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }

    # Tenant DNS publication (ADR-0004). RFC 2136 dynamic update rather than a
    # PowerDNS-native provider: PowerDNS's HTTP API has a single global key, so
    # publishing through it would let any tenant write any zone. A per-zone TSIG
    # key is scoped by the server, which is what ADR-0004's "namespaced"
    # constraint actually asks for.
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}
