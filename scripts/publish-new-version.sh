#!/bin/bash

# Builds, tags, and pushes a new release to GitHub

set -euo pipefail

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
