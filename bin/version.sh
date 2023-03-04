#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

# cspell: words koozz
if gh extension list | grep -q "koozz/gh-semver"; then
    gh extension upgrade koozz/gh-semver &>/dev/null
else
    gh extension install koozz/gh-semver &>/dev/null
fi

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
CURRENT_VERSION=$(gh release view --json tagName --jq .tagName)
NEXT_VERSION=$(gh semver)

echo "Current branch:  $CURRENT_BRANCH" 1>&2
echo "Current version: $CURRENT_VERSION" 1>&2
if [[ "$CURRENT_VERSION" == "$NEXT_VERSION" ]]; then
    echo "🔴 No commits since $CURRENT_VERSION that would trigger a new release - exiting." 1>&2
    exit 0
fi
echo "Next version:    $NEXT_VERSION" 1>&2
