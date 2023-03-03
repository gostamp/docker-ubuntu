#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

APP_ENV="${APP_ENV:?}"
APP_TARGET="${APP_TARGET:?}"

config_path="/app/etc/${APP_ENV}/config.env"
secrets_path="/app/etc/${APP_ENV}/secrets.yml"

# Used by the Makefile to determine whether scripts
# need to be passed through the entrypoint.
export RUNNING_IN_ENTRYPOINT=1

if [[ "${CI:-}" == "true" ]]; then
    echo ""
    echo "CI: true"
    echo "CURRENT_UID: $(id -u)"
    echo "CURRENT_GID: $(id -g)"
    echo ""
    sudo chown -R ci:ci /home/ci
    git config --global --add safe.directory /app
fi

if [ "${APP_TARGET}" == "full" ] && [ "${CI:-}" != "true" ]; then
    # Sigh... get it together Docker for Mac :roll_eyes:
    sudo mkdir -p /run/host-services
    sudo chown -R app:app \
        /app \
        /home/app \
        /run/host-services \
        /run/docker.sock

    # Ensure git hooks are installed.
    mkdir -p .git/hooks && rm -Rf .git/hooks/*
    cp bin/githooks/wrappers/* .git/hooks/
    chmod +x .git/hooks/*
fi

# Source config.env if present
if [[ -f "${config_path}" ]]; then
    set -o allexport
    # shellcheck source=/dev/null
    source "${config_path}"
    set +o allexport
fi

# Use sops if the secrets file exists.
if [[ -f "${secrets_path}" ]]; then
    sops exec-env "${secrets_path}" "$*"
else
    exec "$@"
fi
