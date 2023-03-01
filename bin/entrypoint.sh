#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

APP_ENV="${APP_ENV:?}"
APP_TARGET="${APP_TARGET:?}"

key_path="${SOPS_AGE_KEY_FILE:-/home/app/.config/sops/age/keys.txt}"
config_path="/app/etc/${APP_ENV}/config.env"
secrets_path="/app/etc/${APP_ENV}/secrets.yml"

# Used by the Makefile to determine whether scripts
# need to be passed through the entrypoint.
export RUNNING_IN_ENTRYPOINT=1

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

# Use sops if both secrets.yml and sops-age-key.txt are present.
if
    [[ -f "${secrets_path}" ]] && # exists and is file
        [[ -f "${key_path}" ]] && # exists and is file
        [[ -s "${key_path}" ]]    # exists and has a size greater than zero
then
    sops exec-env "${secrets_path}" "$*"
else
    exec "$@"
fi
