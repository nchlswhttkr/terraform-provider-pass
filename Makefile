.PHONY: release
release-%:
	@RELEASE=$* ./build-release.sh
