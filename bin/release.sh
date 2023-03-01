#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    echo "🔴 Branch '${CURRENT_BRANCH}' is not a release branch - exiting."
    exit 0
fi

git fetch --all --tags
CURRENT_VERSION=$(svu current)
NEXT_VERSION=$(svu next)

echo "Current version: ${CURRENT_VERSION}"
if [[ "${CURRENT_VERSION}" == "${NEXT_VERSION}" ]]; then
    echo "🔴 No commits since ${CURRENT_VERSION} that would trigger a new release - exiting."
    exit 0
fi
echo "Next version:    ${NEXT_VERSION}"

gh release create "${NEXT_VERSION}" --generate-notes
