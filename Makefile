.PHONY: build
build:
	@go build

.PHONY: release
release-%:
	@RELEASE=$* ./build-release.sh
