#!/bin/bash

set -euo pipefail

if grep --fixed-strings "v${RELEASE}" <(git tag --list) > /dev/null; then
    echo -e "\033[31mExisting tag v${RELEASE} found, exiting...\033[0m"
    exit 1
fi

echo "--- Creating tag for release on GitHub"
if ! git diff --exit-code main > /dev/null; then
    echo -e "\033[31mOut of sync with main, please clean up\033[0m"
    exit 1
fi
git checkout main
git tag -m "Craft release v${RELEASE}" "v${RELEASE}"
git push origin main
git push --tags

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

echo "--- Creating a draft release"
GITHUB_ACCESS_TOKEN=$(pass show terraform-provider-pass/github-access-token)
curl --silent --fail -X POST "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "
        {
            \"tag_name\": \"v${RELEASE}\",
            \"draft\": true
        }
    " > "release/${RELEASE}.json"
RELEASE_ID=$(jq --raw-output ".id" "release/${RELEASE}.json")
echo "Created draft release ${RELEASE_ID}"

echo "--- Uploading release assets"
# GitHub supports Hypermedia relations, but this isn't easy to shell script
# https://docs.github.com/en/rest/overview/resources-in-the-rest-api#hypermedia
find "release/${RELEASE}" -type f | while read -r ASSET; do
    echo "Uploading $(basename "${ASSET}")"
    curl --silent --fail -X POST "https://uploads.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}/assets?name=$(basename "${ASSET}")" \
        -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: $(file --brief --mime-type "${ASSET}")" \
        --data-binary "@${ASSET}" > /dev/null
done

echo "--- Making release public"
curl --silent --fail -X PATCH "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "
        {
            \"draft\": false
        }
    " > /dev/null
