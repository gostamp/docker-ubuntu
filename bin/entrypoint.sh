#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

APP_ENV="${APP_ENV:?}"
APP_TARGET="${APP_TARGET:?}"

key_path="${SOPS_AGE_KEY_FILE:?}"
config_path="/app/etc/${APP_ENV}/config.env"
secrets_path="/app/etc/${APP_ENV}/secrets.yaml"

# Used by the Makefile to determine whether scripts
# need to be passed through the entrypoint.
export RUNNING_IN_ENTRYPOINT=1

if [[ "${APP_TARGET}" == "full" ]]; then
    # Sigh... get it together Docker for Mac :roll_eyes:
    sudo chown -R app:app \
        /app \
        /home/app \
        /run/host-services/ssh-auth.sock

    /app/bin/pre-commit-restore.sh
fi

# Source config.env if present
if [ -f "${config_path}" ]; then
    set -o allexport
    # shellcheck source=/dev/null
    source "${config_path}"
    set +o allexport
fi

# Use sops if both secrets.yaml and sops-age-key.txt are present.
if [ -f "${secrets_path}" ] && [ -s "${key_path}" ]; then
    sops exec-env "${secrets_path}" "$*"
else
    exec "$@"
fi
