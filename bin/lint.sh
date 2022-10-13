#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

flags=("--all-files")
if [[ "${DEBUG:-}" != "" ]]; then
    flags+=("--verbose")
fi

pre-commit run "${flags[@]}"
