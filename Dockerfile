# syntax=docker/dockerfile:1.4
#######################################################
# Common base image for each env
# Ubuntu source: https://git.launchpad.net/cloud-images/+oci/ubuntu-base/tree/?h=jammy-22.04
#######################################################
FROM ubuntu:22.04 AS base

ENV APP_GID="10001" \
    APP_UID="10001" \
    APP_HOME="/home/app" \
    APP_DIR="/app" \
    APP_USER="app" \
    LANG="C.utf8" \
    LANGUAGE="C.utf8" \
    LC_ALL="C.utf8" \
    RUNNING_IN_CONTAINER=1

RUN <<EOF
    # Create app user and /app dir
    groupadd --gid "${APP_GID}" "${APP_USER}"
    useradd --gid "${APP_GID}" --uid "${APP_UID}" \
            --shell /bin/bash --create-home --no-log-init "${APP_USER}"
    mkdir -p "${APP_DIR}"
    chown -R "${APP_UID}:${APP_GID}" "${APP_DIR}"
EOF

WORKDIR ${APP_DIR}
ENTRYPOINT ["/app/bin/entrypoint.sh"]
CMD ["/app/bin/run.sh"]

#######################################################
# APP_TARGET: full
#
# All of the dev/test/build tools
#######################################################
FROM base AS full

# Using Bash for docker RUN operations so we can safely pipe.
# See: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-c"]

RUN <<EOF
    # Create CI user
    groupadd --gid 123 "ci"
    useradd --gid 123 --uid 1001 \
            --shell /bin/bash --create-home --no-log-init "ci"
EOF

ARG TARGETARCH
RUN <<EOF
    # Install OS packages
    # Default package manifest:
    # - https://git.launchpad.net/cloud-images/+oci/ubuntu-base/tree/ubuntu-jammy-oci-arm64-root.manifest?h=jammy-22.04
    apt-get update
    apt-get install -y --no-install-recommends \
        "bash-completion=1:2.11-*" \
        "build-essential=12.*" \
        "ca-certificates=20211016" \
        "curl=7.81.*" \
        "git=1:2.34.*" \
        "gnupg=2.2.27-*" \
        "jq=1.6-*" \
        "lsb-release=11.1.*" \
        "nano=6.2-*" \
        "openssh-client=1:8.9p1-*" \
        "python3=3.10.*" \
        "python3-pip=22.0.*" \
        "rcm=1.3.*" \
        "shellcheck=0.8.*" \
        "sudo=1.9.*" \
        "tree=2.0.*"

    # Now that lsb_release and curl are installed...
    DISTRO="$(lsb_release -c -s)"
    # Add Node repo
    echo "deb https://deb.nodesource.com/node_16.x ${DISTRO} main" > /etc/apt/sources.list.d/nodesource.list
    echo "deb-src https://deb.nodesource.com/node_16.x ${DISTRO} main" >> /etc/apt/sources.list.d/nodesource.list
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key > /etc/apt/trusted.gpg.d/nodesource.asc
    # Add Postgres repo
    echo "deb http://apt.postgresql.org/pub/repos/apt ${DISTRO}-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc > /etc/apt/trusted.gpg.d/pgdg.asc
    # Install
    apt-get update
    apt-get install -y --no-install-recommends \
        "nodejs=16.*" \
        "postgresql-client=15+*"

    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

RUN <<EOF
    # Download and install external packages
    set -x
    ACTIONLINT_VERSION="v1.6.24"
    GH_VERSION="v2.27.0"
    GITLEAKS_VERSION="v8.16.2"
    GUM_VERSION="v0.10.0"
    HADOLINT_VERSION="v2.12.0"
    HUGO_VERSION="v0.111.3"
    MIGRATE_VERSION="v4.15.2"
    SHFMT_VERSION="v3.6.0"
    SOPS_VERSION="v3.7.3"
    STYLIST_VERSION="v0.1.1"

    ARCH="${TARGETARCH}"

    curl -fsSL "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_${ARCH}" > /usr/local/bin/shfmt
    curl -fsSL "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}" > /usr/local/bin/sops
    curl -fsSL "https://github.com/twelvelabs/stylist/releases/download/${STYLIST_VERSION}/stylist_${STYLIST_VERSION#v}_linux_${ARCH}" > /usr/local/bin/stylist
    chmod 0755 /usr/local/bin/stylist
    /usr/local/bin/stylist completion bash > /etc/bash_completion.d/stylist

    pushd /tmp >/dev/null || exit
    tarfile="actionlint_${ACTIONLINT_VERSION#v}_linux_${ARCH}.tar.gz"
    checksums="actionlint_${ACTIONLINT_VERSION#v}_checksums.txt"
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/${tarfile}" >"./${tarfile}"
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/${checksums}" >"./${checksums}"
    sha256sum --check --ignore-missing "./${checksums}"
    tar -xzf "./${tarfile}"
    cp ./actionlint /usr/local/bin/actionlint
    popd >/dev/null || exit
    rm -Rf /tmp/*

    pushd /tmp > /dev/null || exit
    tarfile="gh_${GH_VERSION#v}_linux_${ARCH}.tar.gz"
    curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/${tarfile}" > "./${tarfile}"
    curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VERSION#v}_checksums.txt" > ./checksums.txt
    sha256sum --check --ignore-missing ./checksums.txt
    tar -xzf "./${tarfile}"
    cp "./${tarfile%.tar.gz}/bin/gh" /usr/local/bin/gh
    /usr/local/bin/gh completion --shell bash > /etc/bash_completion.d/gh
    popd > /dev/null || exit
    rm -Rf /tmp/*

    pushd /tmp > /dev/null || exit
    tarfile="hugo_extended_${HUGO_VERSION#v}_linux-${ARCH}.tar.gz"
    curl -fsSL "https://github.com/gohugoio/hugo/releases/download/${HUGO_VERSION}/${tarfile}" > "./${tarfile}"
    curl -fsSL "https://github.com/gohugoio/hugo/releases/download/${HUGO_VERSION}/hugo_${HUGO_VERSION#v}_checksums.txt" > ./checksums.txt
    sha256sum --check --ignore-missing ./checksums.txt
    tar -xzf "./${tarfile}"
    ./hugo completion bash > /etc/bash_completion.d/hugo
    cp ./hugo /usr/local/bin/hugo
    popd > /dev/null || exit
    rm -Rf /tmp/*

    pushd /tmp >/dev/null || exit
    tarfile="migrate.linux-${ARCH}.tar.gz"
    checksums="sha256sum.txt"
    curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/${MIGRATE_VERSION}/${tarfile}" >"./${tarfile}"
    curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/${MIGRATE_VERSION}/${checksums}" >"./${checksums}"
    sha256sum --check --ignore-missing "./${checksums}"
    tar -xzf "./${tarfile}"
    cp ./migrate /usr/local/bin/migrate
    popd >/dev/null || exit
    rm -Rf /tmp/*

    # These dependencies use different arch names :/
    if [[ "${TARGETARCH}" == "amd64" ]]; then
        ARCH="x86_64"
    fi
    curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-${ARCH}" > /usr/local/bin/hadolint

    pushd /tmp > /dev/null || exit
    tarfile="gum_${GUM_VERSION#v}_Linux_${ARCH}.tar.gz"
    curl -fsSL "https://github.com/charmbracelet/gum/releases/download/${GUM_VERSION}/${tarfile}" > "./${tarfile}"
    curl -fsSL "https://github.com/charmbracelet/gum/releases/download/${GUM_VERSION}/checksums.txt" > ./checksums.txt
    sha256sum --check --ignore-missing ./checksums.txt
    tar -xzf "./${tarfile}"
    cp ./gum /usr/local/bin/gum
    cp ./completions/gum.bash /etc/bash_completion.d/gum
    popd > /dev/null || exit
    rm -Rf /tmp/*

    # You would think this would be standardized by now :roll_eyes:.
    if [[ "${TARGETARCH}" == "amd64" ]]; then
        ARCH="x64"
    fi
    pushd /tmp > /dev/null || exit
    tarfile="gitleaks_${GITLEAKS_VERSION#v}_linux_${ARCH}.tar.gz"
    curl -fsSL "https://github.com/zricethezav/gitleaks/releases/download/${GITLEAKS_VERSION}/${tarfile}" > "./${tarfile}"
    tar -xzf "./${tarfile}"
    ./gitleaks completion bash > /etc/bash_completion.d/gitleaks
    cp ./gitleaks /usr/local/bin/gitleaks
    popd > /dev/null || exit
    rm -Rf /tmp/*

    chmod -R 0755 /etc/bash_completion.d
    chmod -R 0755 /usr/local/bin
EOF

RUN <<EOF
    # Install Node and Python packages
    npm config set \
        "audit=false" \
        "fund=false" \
        "loglevel=warn" \
        "update-notifier=false"
    npm install \
        "commitizen@~4.3.0" \
        "cz-conventional-changelog@~3.3.0" \
        "cspell@~6.31.1" \
        "markdownlint-cli@~0.33.0" \
        "pin-github-action@~1.8.0" \
        --global
    # some node packages want to write cache files relative to their install path
    chown -R "${APP_UID}:${APP_GID}" /lib/node_modules
    # configure commitizen
    echo '{ "path": "cz-conventional-changelog" }' > "${APP_HOME}/.czrc"

    pip install \
        "gitlint~=0.19.1" \
        --disable-pip-version-check \
        --no-cache-dir
EOF

COPY ./etc/dotfiles/* ${APP_HOME}/
COPY ./bin ${APP_DIR}/bin
RUN <<EOF
    # Allow app user to sudo
    echo "${APP_USER} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${APP_USER}"
    chmod 0440 "/etc/sudoers.d/${APP_USER}"
    # Allow ci user to sudo
    echo "ci ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/ci"
    chmod 0440 "/etc/sudoers.d/ci"

    # Setup home dir
    mkdir -p "${APP_HOME}/.ssh"
    chmod 0700 "${APP_HOME}/.ssh"
EOF

# Drop down to the app user
USER ${APP_USER}

# Keep these lines as low as possible to limit the impact on the build cache.
# See: https://docs.docker.com/engine/reference/builder/#impact-on-build-caching
ARG APP_TARGET
ENV APP_TARGET="${APP_TARGET:-full}" \
    APP_ENV=local

#######################################################
# APP_TARGET: slim
#
# A minimal image w/ just the app
#######################################################
FROM base AS slim

RUN <<EOF
    # Install OS packages
    apt-get update
    apt-get install -y --no-install-recommends \
        "ca-certificates=20211016" \
        "gnupg=2.2.27-*"
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

COPY --from=full /usr/local/bin/sops /usr/local/bin/sops
COPY --from=full ${APP_DIR} ${APP_DIR}

USER ${APP_USER}

ENV APP_TARGET=slim \
    APP_ENV=prod
