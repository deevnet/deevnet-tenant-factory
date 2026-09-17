# Deevnet Tenant Fabric
#
# Credentials are never stored here. The image factory renders them from the
# inventory vault; every target below sources that file.

SHELL := /usr/bin/bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

IMAGE_FACTORY ?= $(CURDIR)/../deevnet-image-factory
PVE_NODE      ?= pve2
PVE_ENV       := $(IMAGE_FACTORY)/build/pve-env/$(PVE_NODE).env

FABRIC  ?= fabric/mobile-dv02hyp002p02

# Extra args for apply/destroy. Terraform prompts for approval by default and
# that is the right default for a human at a terminal; pass AUTO=1 for a
# non-interactive run (no TTY, CI, or an agent driving it).
TF_APPROVE := $(if $(AUTO),-auto-approve,)

.PHONY: help creds fabric-init fabric-plan fabric-apply fmt validate

help:
	@echo "Deevnet tenant fabric - the hypervisor's readiness for tenants."
	@echo
	@echo "  fabric-init    terraform init"
	@echo "  fabric-plan    terraform plan"
	@echo "  fabric-apply   terraform apply       (AUTO=1 to skip approval)"
	@echo "  validate       fmt check + validate"
	@echo
	@echo "Tenants are not built here: the Deevnet API builds them (ADR-0015)."

creds:
	$(MAKE) -C "$(IMAGE_FACTORY)" $(PVE_NODE)-env

$(PVE_ENV):
	$(MAKE) creds

fabric-init: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(FABRIC) init

fabric-plan: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(FABRIC) plan

fabric-apply: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(FABRIC) apply $(TF_APPROVE)

fmt:
	terraform fmt -recursive

validate:
	terraform fmt -check -recursive
	terraform -chdir=$(FABRIC) init -backend=false -input=false >/dev/null
	terraform -chdir=$(FABRIC) validate
