#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

# Guard against someone running the make script from inside the container.
if [[ "${RUNNING_IN_CONTAINER:-}" == "1" ]]; then
    exit 0
fi

# Ensure host dependencies are installed.
dependencies=(
    "docker"
    "gh"
    "gpg"
    "make"
)
for dependency in "${dependencies[@]}"; do
    if command -v "${dependency}" >/dev/null 2>&1; then
        echo "Found required dependency: ${dependency}"
    else
        echo "Unable to find dependency: ${dependency}"
        exit 1
    fi
done

repo_name=$(gh api /repos/:owner/:repo | jq -r .full_name)
if gpg --list-secret-keys "${repo_name}" &>/dev/null; then
    echo "Found required GPG key: ${repo_name}"
else
    echo "Unable to find GPG key: ${repo_name}"
    exit 1
fi

# Build the image.
image_name=$(docker compose convert --images app)
image_id=$(docker images -q "${image_name}")
if [[ "${image_id}" == "" ]]; then
    echo "Building ${image_name}..."
    echo ""
    make docker-build
fi
