# Deevnet Tenant Factory
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

FABRIC  ?= fabric/dvntm-hv02
# No default: tenants live in their own repos, so a bare `make tenant-apply` or
# `make tenant-destroy` must not silently target a live workload that happens to
# still be checked in here.
TENANT  ?=

# Extra args for apply/destroy. Terraform prompts for approval by default and
# that is the right default for a human at a terminal; pass AUTO=1 for a
# non-interactive run (no TTY, CI, or an agent driving it).
TF_APPROVE := $(if $(AUTO),-auto-approve,)

.PHONY: help creds fabric-init fabric-plan fabric-apply require-tenant tenant-init tenant-plan tenant-apply tenant-destroy fmt validate

help:
	@echo "Deevnet Tenant Factory"
	@echo
	@echo "  creds           Render PVE credentials for $(PVE_NODE) from the inventory vault"
	@echo
	@echo "  fabric-plan     Plan the substrate-owned fabric ($(FABRIC))"
	@echo "  fabric-apply    Apply it - build this once, before any tenant"
	@echo
	@echo "  tenant-plan     Plan a tenant        (TENANT=$(TENANT))"
	@echo "  tenant-apply    Create it"
	@echo "  tenant-destroy  Destroy it"
	@echo
	@echo "  fmt validate    Formatting and validation across every stack"
	@echo
	@echo "  AUTO=1          Skip approval prompts (non-interactive runs)"

# The image factory owns credential rendering; don't duplicate it here.
creds:
	$(MAKE) -C "$(IMAGE_FACTORY)" $(PVE_NODE)-env >/dev/null
	@echo "Rendered $(PVE_ENV)"

$(PVE_ENV):
	$(MAKE) creds

fabric-init: $(PVE_ENV)
	terraform -chdir=$(FABRIC) init

fabric-plan: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(FABRIC) plan

fabric-apply: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(FABRIC) apply $(TF_APPROVE)

# TENANT has no default on purpose, so say why rather than letting terraform
# fail on an empty -chdir.
require-tenant:
	@if [[ -z "$(TENANT)" ]]; then
		echo "TENANT is not set." >&2
		echo "Tenants live in their own repositories - run make from the tenant repo," >&2
		echo "or point at one explicitly:" >&2
		echo "  make $(MAKECMDGOALS) TENANT=../deevnet-tenant-<name>" >&2
		exit 2
	fi

tenant-init: require-tenant $(PVE_ENV)
	terraform -chdir=$(TENANT) init

tenant-plan: require-tenant $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) plan

tenant-apply: require-tenant $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) apply $(TF_APPROVE)

tenant-destroy: require-tenant $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) destroy $(TF_APPROVE)

fmt:
	terraform fmt -recursive

validate:
	for d in $(FABRIC) modules/tenant $(TENANT); do
		echo "== $$d"
		terraform -chdir=$$d validate
	done
