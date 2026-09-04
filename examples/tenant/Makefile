# Tenant: REPLACE-ME
#
# This repository is the tenant. Everything that recurs - adding a record,
# rebuilding, destroying - happens here and touches no substrate repository
# (ADR-0004 section 5, ADR-0006).
#
# Two things arrive from the substrate at onboarding and are not authored here:
#   fabric.auto.tfvars       make tenant-attachment TENANT=<this repo>
#   TF_VAR_tsig_key_secret   read from the inventory vault, exported
#
.ONESHELL:
SHELL := /usr/bin/bash
.SHELLFLAGS := -euo pipefail -c

IMAGE_FACTORY ?= $(CURDIR)/../deevnet-image-factory
PVE_NODE      ?= pve2
PVE_ENV       := $(IMAGE_FACTORY)/build/pve-env/$(PVE_NODE).env

TF_APPROVE := $(if $(AUTO),-auto-approve,)

.PHONY: help creds require-secret init plan apply destroy fmt validate

help:
	@echo "REPLACE-ME - tenant repository"
	@echo
	@echo "  init      terraform init (fetches the tagged module; needs GitHub + ssh-agent)"
	@echo "  plan      terraform plan"
	@echo "  apply     terraform apply         (AUTO=1 to skip approval)"
	@echo "  destroy   terraform destroy       (AUTO=1 to skip approval)"
	@echo "  validate  fmt check + validate"
	@echo
	@echo "Requires TF_VAR_tsig_key_secret in the environment - see README."

$(PVE_ENV):
	$(MAKE) creds

creds:
	$(MAKE) -C "$(IMAGE_FACTORY)" $(PVE_NODE)-env

# The TSIG secret is delivery-by-environment on purpose: it is a secret this
# repository must never hold (secure-identity 4.3).
require-secret:
	@if [[ -z "$${TF_VAR_tsig_key_secret:-}" ]]; then
		echo "TF_VAR_tsig_key_secret is not set." >&2
		echo "It is issued by the substrate and lives in the inventory vault." >&2
		echo "  export TF_VAR_tsig_key_secret=\$$(ansible-vault view \\" >&2
		echo "    ../ansible-inventory-deevnet/dvntm/group_vars/all/vault.yml \\" >&2
		echo "    | yq -r .vault_tenant_tsig_keys.REPLACE-ME)" >&2
		exit 2
	fi

init: $(PVE_ENV)
	terraform init

plan: require-secret $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform plan

apply: require-secret $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform apply $(TF_APPROVE)

destroy: require-secret $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform destroy $(TF_APPROVE)

fmt:
	terraform fmt -recursive

validate:
	terraform fmt -check -recursive
	terraform validate
