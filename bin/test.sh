#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

APP_REGISTRY="${APP_REGISTRY:?}"
APP_NAME="${APP_NAME:?}"
APP_TAG="${APP_TAG?}"

for target in "full" "slim"; do
    config_path="tests/${target}/structure-test.yaml"
    image_name="${APP_REGISTRY}/${APP_NAME}-${target}:${APP_TAG}"

    if [ -f "${config_path}" ]; then
        echo ""
        echo "============================================"
        echo "=== CONFIG: ${config_path}"
        echo "=== IMAGE: ${image_name}"
        echo "============================================"

        container-structure-test test \
            --config "${config_path}" \
            --image "${image_name}"
    fi
done
