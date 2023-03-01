#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

APP_NAME="${APP_NAME?}"
APP_TARGET="${APP_TARGET?}"
APP_TAG="${APP_TAG?}"
APP_DOCKER_IMAGE="${APP_DOCKER_IMAGE?}"
APP_DOCKER_REGISTRY="${APP_DOCKER_REGISTRY?}"
APP_DOCKER_USERNAME="${APP_DOCKER_USERNAME?}"
APP_DOCKER_PASSWORD="${APP_DOCKER_PASSWORD?}"

title="${APP_NAME}-${APP_TARGET}"
revision="${GITHUB_SHA:-$(git rev-parse HEAD)}"

# TODO: maybe just use APP_TAG?
version="${GITHUB_REF_NAME:-$(svu current)}"
version="${version#v}"
major="$(echo "${version}" | cut -d "." -f1)"
minor="$(echo "${version}" | cut -d "." -f2)"
patch="$(echo "${version}" | cut -d "." -f3)"

metadata=$(gh repo view --json description,homepageUrl,licenseInfo,url)
description=$(echo "$metadata" | jq -r .description)
url=$(echo "$metadata" | jq -r .homepageUrl)
licenses=$(echo "$metadata" | jq -r .licenseInfo.key)
source=$(echo "$metadata" | jq -r .url)

# Login to the registry.
echo "${APP_DOCKER_PASSWORD}" | docker login "${APP_DOCKER_REGISTRY}" \
    --username "${APP_DOCKER_USERNAME}" \
    --password-stdin 2>/dev/null
# Build and push the image.
docker buildx bake \
    --push \
    --set "app.cache-from=type=registry,ref=${APP_DOCKER_IMAGE}:buildcache" \
    --set "app.cache-to=type=registry,ref=${APP_DOCKER_IMAGE}:buildcache,mode=max" \
    --set "app.labels.org.opencontainers.image.source=${source}" \
    --set "app.labels.org.opencontainers.image.url=${url}" \
    --set "app.labels.org.opencontainers.image.title=${title#docker-}" \
    --set "app.labels.org.opencontainers.image.description=${description}" \
    --set "app.labels.org.opencontainers.image.licenses=${licenses}" \
    --set "app.labels.org.opencontainers.image.version=${version}" \
    --set "app.labels.org.opencontainers.image.revision=${revision}" \
    --set "app.platform=linux/amd64" \
    --set "app.platform=linux/arm64" \
    --set "app.tags=${APP_DOCKER_IMAGE}:latest" \
    --set "app.tags=${APP_DOCKER_IMAGE}:${major}.${minor}.${patch}" \
    --set "app.tags=${APP_DOCKER_IMAGE}:${major}.${minor}" \
    app
