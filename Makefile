.PHONY: build
build:
	@go build

.PHONY: release
release-%:
	@RELEASE=$* ./build-release.sh

goos = $(shell go env GOOS)
goarch = $(shell go env GOARCH)
tfplugindocs_version = 0.13.0
tfplugindocs:
	@curl --silent --fail --location https://github.com/hashicorp/terraform-plugin-docs/releases/download/v$(tfplugindocs_version)/tfplugindocs_$(tfplugindocs_version)_$(goos)_$(goarch).zip | tar -x tfplugindocs
	@chmod +x tfplugindocs

.PHONY: docs
docs: tfplugindocs
	@./tfplugindocs generate

.PHONY: clean
clean:
	@rm -f tfplugindocs
