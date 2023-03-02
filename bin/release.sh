#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail

CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    echo "🔴 Branch '${CURRENT_BRANCH}' is not a release branch - exiting."
    exit 0
fi

git fetch --all --tags
CURRENT_VERSION=$(svu current)
NEXT_VERSION=$(svu next)

echo "Current version: ${CURRENT_VERSION}"
if [[ "${CURRENT_VERSION}" == "v0.0.0" ]]; then
    echo "🔴 Invalid version ${CURRENT_VERSION} - exiting."
    exit 0
fi
if [[ "${CURRENT_VERSION}" == "${NEXT_VERSION}" ]]; then
    echo "🔴 No commits since ${CURRENT_VERSION} that would trigger a new release - exiting."
    exit 0
fi
echo "Next version:    ${NEXT_VERSION}"

APP_NAME="${APP_NAME?}"
APP_TARGET="${APP_TARGET?}"
APP_DOCKER_IMAGE="${APP_DOCKER_IMAGE?}"
APP_DOCKER_REGISTRY="${APP_DOCKER_REGISTRY?}"
APP_DOCKER_USERNAME="${APP_DOCKER_USERNAME?}"
APP_DOCKER_PASSWORD="${APP_DOCKER_PASSWORD?}"

title="${APP_NAME}-${APP_TARGET}"
revision="${GITHUB_SHA:-$(git rev-parse HEAD)}"

version="${NEXT_VERSION#v}"
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

# Create a buildx build node and wait for it to come online.
builder="builder-$(date +%s)"
docker buildx create \
    --name "${builder}" \
    --driver docker-container \
    --use
docker buildx inspect \
    --bootstrap \
    --builder "${builder}"

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

# Clean up the build node.
docker buildx rm \
    --builder "${builder}" \
    --force

# Publish the release.
gh release create "${NEXT_VERSION}" --generate-notes
