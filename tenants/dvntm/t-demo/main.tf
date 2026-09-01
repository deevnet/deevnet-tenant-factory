# Demo tenant - proves the path end to end, then gets destroyed.
#
# Everything about this tenant derives from tenant_index. That is the whole
# point of the numbering scheme: one allocation, no per-tenant decisions, and
# no way to collide with another tenant once the fabric has more members.
#
# Reads the fabric stack's outputs rather than hardcoding the controller or
# node, so a tenant is portable across fabric members without edits.

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }
  }
}

provider "proxmox" {
  endpoint  = replace(var.proxmox_url, "/api2/json", "")
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}

data "terraform_remote_state" "fabric" {
  backend = "local"

  config = {
    path = "${path.module}/../../../fabric/dvntm-hv02/terraform.tfstate"
  }
}

module "tenant" {
  source = "../../../modules/tenant"

  tenant_name  = "tdemo"
  tenant_index = 1

  controller_id = data.terraform_remote_state.fabric.outputs.controller_id
  node          = data.terraform_remote_state.fabric.outputs.node


  template_vm_id = var.template_vm_id
  vm_count       = 1
  ssh_keys       = var.ssh_keys
}

output "subnet" {
  value = module.tenant.subnet
}

output "gateway" {
  value = module.tenant.gateway
}

output "vrf_vni" {
  value = module.tenant.vrf_vni
}

output "vnet_ids" {
  value = module.tenant.vnet_ids
}

output "vm_names" {
  value = module.tenant.vm_names
}
