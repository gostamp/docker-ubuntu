#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    echo "🔴 Branch '${CURRENT_BRANCH}' is not a release branch - exiting."
    exit 0
fi

# The github CLI will complain if the repo isn't owned
# by the current user (for example, in CI).
repo_owner_uid=$(stat -c '%u' "${APP_DIR}")
current_user_uid=$(id -u)
if [[ "${repo_owner_uid}" != "${current_user_uid}" ]]; then
    git config --global --add safe.directory /app
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
