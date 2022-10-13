#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

# Restores the pre-commit hooks baked into the image by `pre-commit-build.sh`.

mkdir -p /app/.git/hooks
cp --update /opt/build/git/* /app/.git/hooks/
