#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

MSG_FILE="${1}"
if grep -qE '^[^#]' "${MSG_FILE}"; then
    # A message has already been supplied via `git commit -m`,
    # so we don't want to bother them with commitizen.
    exit 0
fi

# shellcheck disable=SC2015
exec </dev/tty && cz --hook || true
