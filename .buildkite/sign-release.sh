#!/bin/bash

set -euo pipefail

RELEASE=${BUILDKITE_TAG#v}
RELEASE_ID="$(buildkite-agent meta-data get github-release-id)"

VAULT_TOKEN="$(pass show vault/root-token)"
export VAULT_TOKEN
GITHUB_ACCESS_TOKEN="$(vault kv get -mount=kv -field github_access_token buildkite/terraform-provider-pass)"

echo "--- Signing release checksum"
buildkite-agent artifact download "terraform-provider-pass_${RELEASE}_SHA256SUMS" .
gpg --detach-sign "terraform-provider-pass_${RELEASE}_SHA256SUMS"
# GitHub supports Hypermedia relations, but this isn't easy to shell script
# https://docs.github.com/en/rest/overview/resources-in-the-rest-api#hypermedia
curl --silent --fail --show-error -X POST "https://uploads.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}/assets?name=terraform-provider-pass_${RELEASE}_SHA256SUMS.sig" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: $(file --brief --mime-type "terraform-provider-pass_${RELEASE}_SHA256SUMS.sig")" \
    --data-binary "@terraform-provider-pass_${RELEASE}_SHA256SUMS.sig" > /dev/null

echo "--- Publishing release"
curl --silent --fail --show-error -X PATCH "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "{\"draft\": false}"
