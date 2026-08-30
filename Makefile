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
TENANT  ?= tenants/dvntm/t-demo

.PHONY: help creds fabric-init fabric-plan fabric-apply tenant-init tenant-plan tenant-apply tenant-destroy fmt validate

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
	terraform -chdir=$(FABRIC) apply

tenant-init: $(PVE_ENV)
	terraform -chdir=$(TENANT) init

tenant-plan: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) plan

tenant-apply: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) apply

tenant-destroy: $(PVE_ENV)
	source "$(PVE_ENV)"
	terraform -chdir=$(TENANT) destroy

fmt:
	terraform fmt -recursive

validate:
	for d in $(FABRIC) modules/tenant $(TENANT); do
		echo "== $$d"
		terraform -chdir=$$d validate
	done
