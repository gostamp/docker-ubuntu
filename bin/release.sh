#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

if [[ "${CI:-}" != "true" ]]; then
    echo "🔴 Release task should only be run in CI!"
    exit 1
fi

# shellcheck source=version.sh
source /app/bin/version.sh

pre=""
if echo "$NEXT_VERSION" | grep -q "-"; then
    pre="--prerelease"
fi

if [[ "$CURRENT_VERSION" != "$NEXT_VERSION" ]]; then
    # TODO: create a signed tag and add `--verify-tag` to the release step
    gh release create "$NEXT_VERSION" --generate-notes $pre
else
    echo "Nothing to release."
fi
