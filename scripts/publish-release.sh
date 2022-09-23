#!/bin/bash

# Builds, tags, and pushes a new release to GitHub

set -euo pipefail

function get_latest_build_number_for_commit () {
    # $1 - The commit SHA
    curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds?branch=main&commit=${RELEASE_COMMIT}&per_page=1" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
        | jq --raw-output ".[0].number"
}

function wait_for_build_to_pass () {
    # $1 - The Buildkite build number
    local build_state=""
    while [[ ! "${build_state}" =~ (passed|blocked|failing|failed) ]]; do
        sleep 15
        echo "Build is currently in progress..."
        build_state=$(
            curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds/$1" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
                | jq --raw-output ".state"
        )

    done
    echo "Buildkite build $1 stopped with state ${build_state}"
    if [[ "${build_state}" == "passed" ]]; then
        return 0;
    fi
    return 1
}

PREVIOUS_RELEASE_TAG="$(git describe --abbrev=0)"
read -rp "Enter release version (previously ${PREVIOUS_RELEASE_TAG}) > v" RELEASE;
mkdir -p "release/${RELEASE}"

# Ensure version number is valid and does not already exist
if ! [[ "${RELEASE}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\033[31mRelease version number does not satisfy pattern\033[0m"
    exit 1
fi
if grep --fixed-strings --line-regexp "v${RELEASE}" <(git tag --list) > /dev/null; then
    echo -e "\033[33mTag v${RELEASE} already exists, skipping tag push/build\033[0m"
else
    echo "--- Creating and pushing tag for release"
    TAG_MESSAGE=$(mktemp)
    git log --format="%s" "${PREVIOUS_RELEASE_TAG}..main" \
        | sed "s/^/* /" \
        | cat <(echo "v${RELEASE}") <(echo "") - > "${TAG_MESSAGE}"
    git tag --file="${TAG_MESSAGE}" --edit "v${RELEASE}" "main"
    git push origin main
    git push --tags
fi

echo "--- Fetching latest build for v${RELEASE} on Buildkite"
BUILDKITE_API_TOKEN=$(pass show terraform-provider-pass/buildkite-api-token)
RELEASE_COMMIT=$(git show --format="%H" --no-patch)
BUILDKITE_BUILD_NUMBER=$(get_latest_build_number_for_commit "${RELEASE_COMMIT}")
wait_for_build_to_pass "${BUILDKITE_BUILD_NUMBER}"

echo "--- Crafting release v${RELEASE}"
ARTIFACTS_RESPONSE=$(mktemp)
curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds/${BUILDKITE_BUILD_NUMBER}/artifacts" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" > "${ARTIFACTS_RESPONSE}"
for os in darwin linux; do
    for arch in amd64 arm64; do
        DOWNLOAD_URL=$(jq --raw-output ".[] | select(.path == \"terraform-provider-pass_${os}_${arch}\") | .download_url" "${ARTIFACTS_RESPONSE}")
        curl --silent --fail --show-error "${DOWNLOAD_URL}" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" > "terraform-provider-pass_v${RELEASE}"
        chmod +x "terraform-provider-pass_v${RELEASE}"
        zip "release/${RELEASE}/terraform-provider-pass_${RELEASE}_${os}_${arch}.zip" "terraform-provider-pass_v${RELEASE}"
    done
done

echo "--- Generate signed checksums"
cd "release/${RELEASE}"
shasum --algorithm 256 -- *.zip > "terraform-provider-pass_${RELEASE}_SHA256SUMS"
gpg --detach-sign "terraform-provider-pass_${RELEASE}_SHA256SUMS"
cd ../..

echo "--- Creating a draft release"
GITHUB_ACCESS_TOKEN=$(pass show terraform-provider-pass/github-access-token)
curl --silent --fail --show-error -X POST "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases" \
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
    curl --silent --fail --show-error -X POST "https://uploads.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}/assets?name=$(basename "${ASSET}")" \
        -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: $(file --brief --mime-type "${ASSET}")" \
        --data-binary "@${ASSET}" > /dev/null
done

echo "--- Making release public"
curl --silent --fail --show-error -X PATCH "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases/${RELEASE_ID}" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "
        {
            \"draft\": false
        }
    " > /dev/null
