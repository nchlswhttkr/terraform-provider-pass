#!/bin/bash

set -euo pipefail

buildkite-agent artifact download "terraform-provider-pass*" .

RELEASE=${BUILDKITE_TAG#v}

for os in darwin linux; do
    for arch in amd64 arm64; do
        cp "terraform-provider-pass_${os}_${arch}" "terraform-provider-pass_v${RELEASE}"
        chmod +x "terraform-provider-pass_v${RELEASE}"
        zip "terraform-provider-pass_${RELEASE}_${os}_${arch}.zip" "terraform-provider-pass_v${RELEASE}"
    done
done

zip "release.zip" terraform-provider-pass*.zip
