#!/bin/bash

set -euo pipefail

RELEASE=${BUILDKITE_TAG#v}

GITHUB_ACCESS_TOKEN="$(vault kv get -mount=kv -field github_access_token buildkite/terraform-provider-pass)"

echo "--- Downloading and zipping artifacts"
buildkite-agent artifact download "terraform-provider-pass*" .
mkdir -p release
for os in darwin linux; do
    for arch in amd64 arm64; do
        cp "terraform-provider-pass_${os}_${arch}" "terraform-provider-pass_v${RELEASE}"
        chmod +x "terraform-provider-pass_v${RELEASE}"
        zip "release/terraform-provider-pass_${RELEASE}_${os}_${arch}.zip" "terraform-provider-pass_v${RELEASE}"
    done
done

echo "--- Generating checksum for zipped artifacts"
cd release
sha256sum -- *.zip > "terraform-provider-pass_${RELEASE}_SHA256SUMS"
buildkite-agent artifact upload "terraform-provider-pass_${RELEASE}_SHA256SUMS"
cd ..

echo "--- Create draft release on GitHub"
IS_PRELEASE=false
if [[ "${RELEASE}" =~ - ]]; then
    echo "This release will be marked as a prerelease"
    IS_PRELEASE=true
fi
curl --silent --fail --show-error -X POST "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "
        {
            \"tag_name\": \"v${RELEASE}\",
            \"prerelease\": ${IS_PRELEASE},
            \"draft\": true
        }
    " | tee "release.json"
RELEASE_ID=$(jq --raw-output ".id" "release.json")
buildkite-agent meta-data set "github-release-id" "${RELEASE_ID}"
echo "Created draft release ${RELEASE_ID}"

echo "--- Uploading release artifacts"
# GitHub supports Hypermedia relations, but this isn't easy to shell script
# https://docs.github.com/en/rest/overview/resources-in-the-rest-api#hypermedia
find "release/" -type f | while read -r ASSET; do
    echo "Uploading $(basename "${ASSET}")"
    curl --silent --fail --show-error -X POST "https://uploads.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}/assets?name=$(basename "${ASSET}")" \
        -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: $(file --brief --mime-type "${ASSET}")" \
        --data-binary "@${ASSET}" > /dev/null
done
