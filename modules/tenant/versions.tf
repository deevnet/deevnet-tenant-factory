# Without this, Terraform infers hashicorp/proxmox for the proxmox_* resources
# and fails to find a provider.
terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }
  }
}
