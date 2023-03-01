#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

# Run all staged paths through stylist.
# - `readarray` syntax re: https://www.shellcheck.net/wiki/SC2046
# - `diff-filter=d` excludes deleted paths.
readarray -t staged_paths < <(git diff --diff-filter=d --name-only --staged)
if [ ! ${#staged_paths[@]} -eq 0 ]; then
    # TODO: add `--color` flag once available
    stylist check "${staged_paths[@]}" # expand array as args
fi
