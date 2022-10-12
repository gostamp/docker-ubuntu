#!/usr/bin/env bash

# See: https://steinbaugh.com/posts/shell-strict-mode.html
set -o errexit -o errtrace -o nounset -o pipefail

# The `errexit` config above will cause our scripts to fail at the first command
# that doesn't exit cleanly (which is great for catching bugs).
# But unfortunately not all commands exit noisily, so lets always notify users on error.
# shellcheck disable=SC2154
trap $'s=$?; echo "$0: Error on line ${LINENO}: command \'${BASH_COMMAND}\' exited ${s}" >&2; exit $s' ERR
