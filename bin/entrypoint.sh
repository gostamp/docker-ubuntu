#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"


current_env="${APP_ENV:?}"
key_path="${SOPS_AGE_KEY_FILE:?}"
dotenv_path="/app/etc/${current_env}/config.env"
secrets_path="/app/etc/${current_env}/secrets.yaml"

# Source config.env if present
if [ -f "${dotenv_path}" ]
then
    set -o allexport
    # shellcheck source=/dev/null
    source "${dotenv_path}"
    set +o allexport
fi

# Use sops if both secrets.yaml and sops-age-key.txt are present.
if  [ -f "${secrets_path}" ] && [ -s "${key_path}" ]
then
    sops exec-env "${secrets_path}" "$@"
else
    exec "$@"
fi
