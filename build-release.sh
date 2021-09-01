#!/bin/bash

set -euo pipefail

if [ -d "release/${RELEASE}" ]; then
    echo -e "\033[31mExisting release found, exiting...\033[0m"
    exit 1
fi

if ! git diff --exit-code main > /dev/null; then
    echo -e "\033[31mOut of sync with main, please clean up\033[0m"
    exit 1
fi

git tag -m "Craft release v${RELEASE}" "v${RELEASE}" main

echo "--- Building provider"
# Just care about building for my MBP for now
export GOOS="darwin"
export GOARCH="amd64"
go build -o "terraform-provider-pass_v${RELEASE}"

echo "--- Crafting release v${RELEASE}"
mkdir -p "release/${RELEASE}/"
zip "release/${RELEASE}/terraform-provider-pass_${RELEASE}_${GOOS}_${GOARCH}.zip" "terraform-provider-pass_v${RELEASE}"
cd "release/${RELEASE}"

echo "--- Generate signed checksums"
shasum --algorithm 256 -- *.zip > "terraform-provider-pass_${RELEASE}_SHA256SUMS"
gpg --detach-sign "terraform-provider-pass_${RELEASE}_SHA256SUMS"

