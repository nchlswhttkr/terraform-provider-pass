#!/bin/bash

# Builds, tags, and pushes a new release to GitHub

set -euo pipefail

function get_latest_build_number_for_tag () {
    # $1 - The tag name
    curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds?branch=${1}&per_page=1" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
        | jq --raw-output ".[0].number"
}

function wait_for_build_to_pass () {
    # $1 - The Buildkite build number
    local build_state=""
    while [[ ! "${build_state}" =~ (passed|blocked|failing|failed) ]]; do
        sleep 15
        build_state=$(
            curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds/${1}" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
                | jq --raw-output ".state"
        )

    done
    echo "Buildkite build $1 stopped with state ${build_state}"
    if [[ "${build_state}" == "passed" ]]; then
        return 0;
    fi
    return 1
}

function download_artifact_from_build () {
    # $1 - The artifact's full path (not glob syntax)
    # $2 - The number of the Buildkite build to download from
    local grant_url
    grant_url=$(
        curl --silent --fail --show-error "https://api.buildkite.com/v2/organizations/nchlswhttkr/pipelines/terraform-provider-pass/builds/${2}/artifacts" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
            | jq --raw-output ".[] | select(.path == \"${1}\") | .download_url"
    )
    local download_url
    download_url=$(
        curl --silent --fail --show-error "${grant_url}" -H "Authorization: Bearer ${BUILDKITE_API_TOKEN}" \
            | jq --raw-output ".url"
    )
    curl --silent --fail --show-error "${download_url}" > "${1}"
}

PREVIOUS_RELEASE_TAG="$(git describe --abbrev=0 --exclude='*-*')"
read -rp "Enter release version (found ${PREVIOUS_RELEASE_TAG} previously) > v" RELEASE;
mkdir -p "release/${RELEASE}"

# Ensure version number is valid
if ! [[ "${RELEASE}" =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+(-[[:alnum:]]+)?$ ]]; then
    echo -e "\033[31mRelease version number does not satisfy pattern\033[0m"
    exit 1
fi
if grep --fixed-strings --line-regexp "v${RELEASE}" <(git tag --list) > /dev/null; then
    echo -e "\033[33mTag v${RELEASE} already exists, skipping tag push/build\033[0m"
else
    echo "--- Creating and pushing tag for release"
    TAG_MESSAGE=$(mktemp)
    git log --format="%s" "${PREVIOUS_RELEASE_TAG}..HEAD" \
        | sed "s/^/* /" \
        | cat <(echo "v${RELEASE}") <(echo "") - > "${TAG_MESSAGE}"
    git tag --file="${TAG_MESSAGE}" --edit "v${RELEASE}"
    git push --tags origin HEAD
fi

echo "--- Fetching latest build for v${RELEASE} on Buildkite"
BUILDKITE_API_TOKEN=$(pass show terraform-provider-pass/buildkite-api-token)
BUILDKITE_BUILD_NUMBER=$(get_latest_build_number_for_tag "v${RELEASE}")
wait_for_build_to_pass "${BUILDKITE_BUILD_NUMBER}"

echo "--- Crafting release v${RELEASE}"
download_artifact_from_build release.zip "${BUILDKITE_BUILD_NUMBER}"
unzip release.zip -d "release/${RELEASE}"
rm release.zip

echo "--- Generate signed checksums"
cd "release/${RELEASE}"
shasum --algorithm 256 -- *.zip > "terraform-provider-pass_${RELEASE}_SHA256SUMS"
gpg --detach-sign "terraform-provider-pass_${RELEASE}_SHA256SUMS"
cd ../..

echo "--- Creating a draft release"
GITHUB_ACCESS_TOKEN=$(pass show terraform-provider-pass/github-access-token)
PRERELEASE=false
if [[ "${RELEASE}" =~ - ]]; then
    echo -e "\033[33mThis release will be marked as a prerelease\033[0m"
    PRERELEASE=true
fi
curl --silent --fail --show-error -X POST "https://api.github.com/repos/nchlswhttkr/terraform-provider-pass/releases" \
    -H "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    --data "
        {
            \"tag_name\": \"v${RELEASE}\",
            \"prerelease\": ${PRERELEASE},
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
