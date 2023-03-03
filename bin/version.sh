#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${CURRENT_BRANCH}" == "main" ]]; then
    echo "Current branch:  $CURRENT_BRANCH"
else
    echo "🔴 Branch '$CURRENT_BRANCH' is not a release branch - exiting."
    exit 0
fi

# cspell: words koozz
if gh extension list | grep -q "koozz/gh-semver"; then
    gh extension upgrade koozz/gh-semver >/dev/null
else
    gh extension install koozz/gh-semver >/dev/null
fi

CURRENT_VERSION=$(gh release view --json tagName --jq .tagName)
NEXT_VERSION=$(gh semver)

echo "Current version: $CURRENT_VERSION"
if [[ "$CURRENT_VERSION" == "$NEXT_VERSION" ]]; then
    echo "🔴 No commits since $CURRENT_VERSION that would trigger a new release - exiting."
    exit 0
fi
echo "Next version:    $NEXT_VERSION"

# Set the `next_version` output parameter on the workflow step.
echo "next_version=$NEXT_VERSION" >>"${GITHUB_OUTPUT:-/dev/null}"
