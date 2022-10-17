# syntax=docker/dockerfile:1.4
#######################################################
# Common base image for each env
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

# Create app user and /app dir
RUN <<EOF
    groupadd --gid "${APP_GID}" "${APP_USER}"
    useradd --gid "${APP_GID}" --uid "${APP_UID}" \
            --shell /bin/bash --create-home --no-log-init "${APP_USER}"
    mkdir -p "${APP_DIR}"
    chown -R "${APP_UID}:${APP_GID}" "${APP_DIR}"
EOF

WORKDIR ${APP_DIR}
ENTRYPOINT ["/app/bin/entrypoint.sh"]
CMD ["/app/bin/command.sh"]

#######################################################
# APP_TARGET: full
#
# All of the dev/test/build tools
#######################################################
FROM base AS full

# Using Bash for docker RUN operations so we can safely pipe.
# See: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-c"]

ARG TARGETARCH
RUN <<EOF
    apt-get update
    apt-get install -y --no-install-recommends \
        "age=1.0.*" \
        "bash-completion=1:2.11-*" \
        "build-essential=12.*" \
        "ca-certificates=20211016" \
        "curl=7.81.*" \
        "gh=2.4.*" \
        "git=1:2.34.*" \
        "gnupg=2.2.*" \
        "jq=1.6-*" \
        "locales=2.35-*" \
        "nano=6.2-*" \
        "openssh-client=1:8.9p1-*" \
        "pkg-config=0.29.*" \
        "python3=3.10.*" \
        "python3-pip=22.0.*" \
        "shellcheck=0.8.*" \
        "sudo=1.9.*" \
        "tree=2.0.*"
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

    # non-packaged dependencies
    CST_VERSION="v1.11.0"
    DOTENV_LINTER_VERSION="v3.2.0"
    EC_VERSION="2.6.0"
    GITLEAKS_VERSION="v8.15.0"
    GUM_VERSION="v0.7.0"
    HADOLINT_VERSION="v2.10.0"
    HUGO_VERSION="v0.104.3"
    LICENSE_VERSION="v5.0.4"
    SHFMT_VERSION="v3.5.1"
    SOPS_VERSION="v3.7.3"
    YQ_VERSION="v4.28.1"

    ARCH="${TARGETARCH}"

    # None of the following prints anything to stdout,
    # so turn on echoing so it doesn't look like the build is stuck.
    set -x

    curl -fsSL "https://storage.googleapis.com/container-structure-test/${CST_VERSION}/container-structure-test-linux-${ARCH}" > /usr/local/bin/container-structure-test
    curl -fsSL "https://github.com/nishanths/license/releases/download/${LICENSE_VERSION}/license-${LICENSE_VERSION}-linux-${ARCH}" > /usr/local/bin/license
    curl -fsSL "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_${ARCH}" > /usr/local/bin/shfmt
    curl -fsSL "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}" > /usr/local/bin/sops
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" > /usr/local/bin/yq

    pushd /tmp > /dev/null || exit
    curl -fsSL "https://github.com/editorconfig-checker/editorconfig-checker/releases/download/${EC_VERSION}/ec-linux-${ARCH}.tar.gz" > "./ec-linux-${ARCH}.tar.gz"
    tar -xzf "./ec-linux-${ARCH}.tar.gz"
    cp ./bin/ec-linux-${ARCH} /usr/local/bin/ec
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

    # These dependencies use different arch names :/
    if [[ "${TARGETARCH}" == "amd64" ]]; then
        ARCH="x86_64"
    fi
    curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-${ARCH}" > /usr/local/bin/hadolint

    pushd /tmp > /dev/null || exit
    tarfile="gum_${GUM_VERSION#v}_linux_${ARCH}.tar.gz"
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

    # oh, ffs... :dissapointed:.
    if [[ "${TARGETARCH}" == "amd64" ]]; then
        ARCH="x86_64"
    elif [[ "${TARGETARCH}" == "arm64" ]]; then
        ARCH="aarch64"
    fi
    pushd /tmp > /dev/null || exit
    tarfile="dotenv-linter-linux-${ARCH}.tar.gz"
    curl -fsSL "https://github.com/dotenv-linter/dotenv-linter/releases/download/${DOTENV_LINTER_VERSION}/${tarfile}" > "./${tarfile}"
    tar -xzf "./${tarfile}"
    cp ./dotenv-linter /usr/local/bin/dotenv-linter
    popd > /dev/null || exit
    rm -Rf /tmp/*

    chmod -R 0755 /etc/bash_completion.d
    chmod -R 0755 /usr/local/bin

    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y --no-install-recommends "nodejs=16.*"
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

RUN <<EOF
    npm config set \
        "audit=false" \
        "fund=false" \
        "loglevel=warn" \
        "update-notifier=false"
    npm install \
        "cspell@~6.12.0" \
        "eslint@~8.25.0" \
        "eslint-config-prettier@~8.5.0" \
        "eslint-plugin-jsonc@~2.4.0" \
        "eslint-plugin-json-schema-validator@~4.0.2" \
        "eslint-plugin-toml@~0.3.1" \
        "eslint-plugin-yml@~1.2.0" \
        "markdownlint-cli@~0.32.2" \
        "prettier@~2.7.1" \
        "prettier-plugin-ini@~1.1.0" \
        "prettier-plugin-sql@~0.12.1" \
        "semantic-release@~19.0.5" \
        --global
    # some node packages want to write cache files relative to their install path
    chown -R "${APP_UID}:${APP_GID}" /lib/node_modules

    pip install \
        "commitizen~=2.35.0" \
        "gitlint~=0.17.0" \
        "pre-commit~=2.20.0" \
        --disable-pip-version-check \
        --no-cache-dir
EOF

COPY ./etc/dotfiles/* ${APP_HOME}/
COPY ./bin/pre-commit-* /usr/local/bin/
COPY .pre-commit-config.yaml ${APP_DIR}/
RUN <<EOF
    # Creates pre-commit hooks and stores them in /opt/build
    # so that they can be restored into .git/hooks on container start.
    /usr/local/bin/pre-commit-build.sh

    # Allow app user to sudo
    echo 'app ALL=(root) NOPASSWD:ALL' > /etc/sudoers.d/app
    chmod 0440 /etc/sudoers.d/app

    # Setup home dir
    mkdir -p "${APP_HOME}/.ssh"
    chmod 0700 "${APP_HOME}/.ssh"
    chown -R "${APP_UID}:${APP_GID}" "${APP_HOME}"
EOF

# Drop down to the app user
USER ${APP_USER}

# Keep these lines as low as possible to limit the impact on the build cache.
# See: https://docs.docker.com/engine/reference/builder/#impact-on-build-caching
ARG APP_TARGET
ENV APP_TARGET=${APP_TARGET} \
    APP_ENV=local

#######################################################
# APP_TARGET: slim
#
# A minimal image w/ just the app
#######################################################
FROM base AS slim

COPY --from=full ${APP_DIR} ${APP_DIR}
COPY --from=full ${APP_HOME} ${APP_HOME}

USER ${APP_USER}

ENV APP_TARGET=slim \
    APP_ENV=prod
