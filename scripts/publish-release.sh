#!/bin/bash

# Builds, tags, and pushes a new release to GitHub

set -euo pipefail

PREVIOUS_RELEASE_TAG="$(git describe --abbrev=0)"
read -rp "Enter release version (previously ${PREVIOUS_RELEASE_TAG}) > v" RELEASE;

# Ensure version number is valid and does not already exist
if ! [[ "${RELEASE}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\033[31mRelease version number does not satisfy pattern\033[0m"
    exit 1
fi
if grep --fixed-strings --line-regexp "v${RELEASE}" <(git tag --list) > /dev/null; then
    echo -e "\033[31mA release with this version number already exists\033[0m"
    exit 1
fi

echo "--- Creating tag for release"
TAG_MESSAGE=$(mktemp)
git log --format="%s" "${PREVIOUS_RELEASE_TAG}..main" \
    | sed "s/^/* /" \
    | cat <(echo "Craft release v${RELEASE}") <(echo "") - > "${TAG_MESSAGE}"
git tag --file="${TAG_MESSAGE}" --edit "v${RELEASE}" "main"
git stash push --include-untracked --quiet --message "Stashing before release v${RELEASE}"
git checkout --quiet "v${RELEASE}"
git clean -d --force --quiet
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

echo "--- Generate signed checksums"
cd "release/${RELEASE}"
shasum --algorithm 256 -- *.zip > "terraform-provider-pass_${RELEASE}_SHA256SUMS"
gpg --detach-sign "terraform-provider-pass_${RELEASE}_SHA256SUMS"
cd ../..

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
