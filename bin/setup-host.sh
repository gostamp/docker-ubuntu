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
    "make"
)
for dependency in "${dependencies[@]}"; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
        echo "Unable to find dependency: ${dependency}"
        exit 1
    fi
done

# Ensure the sops key file exists (compose will error if missing)
mkdir -p ~/.sops
touch ~/.sops/sops-age-key.txt
chmod 0600 ~/.sops/sops-age-key.txt

# Build the image.
image_name=$(docker compose convert --images app)
image_id=$(docker images -q "${image_name}")
if [[ "${image_id}" == "" ]]; then
    echo "Building ${image_name}..."
    echo ""
    make docker-build
fi
