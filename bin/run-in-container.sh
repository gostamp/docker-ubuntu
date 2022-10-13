#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

# Execs a command in the devcontainer.
# Safe to run from either the host _or_ the container
# (it inspects the environment and invokes the correct command).

if [[ "${DEBUG:-}" != "" ]]; then
    echo "run-in-container: $*"
fi

if [[ "${RUNNING_IN_CONTAINER:-}" != "1" ]]; then
    exec docker-compose run --rm app "$@"
elif [[ "${RUNNING_IN_ENTRYPOINT:-}" != "1" ]]; then
    # VS Code terminal sessions when using devcontainers do not use
    # the ENTRYPOINT defined in the Dockerfile. :shrug:
    exec /app/bin/entrypoint.sh "$@"
else
    exec "$@"
fi
