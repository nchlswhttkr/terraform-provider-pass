SHELL=/bin/bash -o pipefail

.PHONY: build
build:
	@go build

.PHONY: release
release:
	@./scripts/publish-new-version.sh

goos = $(shell go env GOOS)
goarch = $(shell go env GOARCH)
tfplugindocs_version = 0.13.0
tfplugindocs:
	@curl --silent --fail --show-error --location https://github.com/hashicorp/terraform-plugin-docs/releases/download/v$(tfplugindocs_version)/tfplugindocs_$(tfplugindocs_version)_$(goos)_$(goarch).zip > tfplugindocs.zip
	@unzip tfplugindocs.zip tfplugindocs
	@rm tfplugindocs.zip
	@chmod +x tfplugindocs

.PHONY: docs
docs: tfplugindocs
	@./tfplugindocs generate

.PHONY: clean
clean:
	@git clean -d --force --quiet -X
