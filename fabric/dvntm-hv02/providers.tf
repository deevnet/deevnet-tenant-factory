# Provider wiring for the dvntm tenant fabric on hv02.
#
# Credentials are never held here. The image factory already renders them out
# of the inventory vault into a mode-0600 env file:
#
#   cd ../deevnet-image-factory && eval "$(make -s pve2-env)"
#
# which exports TF_VAR_proxmox_* for the variables declared in variables.tf.
# See standards/secure-identity.md 4.3 - IaC references secret locations, not
# secret values.

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # The provider's supported target is PVE 9.x, which is what hv02 now
      # runs. Pinned to a minor series: SDN fabric support is recent and the
      # short-form proxmox_sdn_* resources are still settling.
      version = "~> 0.101"
    }
  }
}

provider "proxmox" {
  # The shared env file carries Packer's endpoint form, which ends in
  # /api2/json; bpg/proxmox wants the base URL and appends its own path.
  # Normalising here means one credentials file serves both tools.
  endpoint  = replace(var.proxmox_url, "/api2/json", "")
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}
