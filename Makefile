.DEFAULT_GOAL := help
SHELL := /bin/bash

# Lazily create and "source" the .env file
# See: https://unix.stackexchange.com/a/235254
ifeq (,$(wildcard .env))
    $(shell cp .env.example .env)
endif
include .env
export $(shell sed 's/=.*//' .env)

ifeq ($(CI),true)
    # In CI we need to create a dummy placeholder for the socket file
    # that the compose file is attempting to bind mount.
    $(shell touch .dummy)
    export DOCKER_DESKTOP_SOCK := $(shell echo "$$(pwd)/.dummy")
    # Ensure file exists for another compose bind mount.
    $(shell touch ~/.gitconfig)
    export APP_USER := $(shell id -u):$(shell id -g)
endif

# Always use buildkit
export DOCKER_BUILDKIT := 1
export GITHUB_TOKEN ?= $(shell gh auth token)

export APP_DOCKER_IMAGE := ${APP_DOCKER_REGISTRY}/${APP_OWNER}/${APP_NAME}-${APP_TARGET}
export APP_DOCKER_USERNAME ?= $(shell gh api /user --jq .login)
export APP_DOCKER_PASSWORD ?= ${GITHUB_TOKEN}

# Support running make commands from both host and container.
ifneq ($(RUNNING_IN_CONTAINER),1)
    # Docker compose runs interactively by default, but git hooks run non-interactively.
    # Docker will error if there's a mismatch.
    # `-t 0` returns true if file descriptor 0 is a terminal (https://stackoverflow.com/a/911213/1582608).
    run_tty := $(shell [ ! -t 0 ] && echo '--no-TTY ')
    run = docker compose run --rm $(run_tty)app
else ifneq ($(RUNNING_IN_ENTRYPOINT),1)
    run = /app/bin/entrypoint.sh
else
    run =
endif


##@ App

.PHONY: lint
lint: ## Lint files
	$(run) ./bin/lint.sh

.PHONY: format
format: ## Format files
	$(run) ./bin/format.sh

.PHONY: run
run: ## Run the container
	$(run) ./bin/command.sh

.PHONY: release
release: ## Create a new release tag
	$(run) ./bin/release.sh

.PHONY: publish
publish: ## Publish a new release
	$(run) ./bin/publish.sh

.PHONY: shell
shell: ## Shell into the container
	$(run) bash

.PHONY: test
test: APP_ENV := test
test: ## Test the container
	$(run) ./bin/test.sh

.PHONY: pre-commit
pre-commit:
	$(run) ./bin/githooks/pre-commit.sh

.PHONY: prepare-commit-msg
prepare-commit-msg:
	$(run) ./bin/githooks/prepare-commit-msg.sh $(MSG_FILE)

.PHONY: commit-msg
commit-msg:
	$(run) ./bin/githooks/commit-msg.sh $(MSG_FILE)


##@ Docker

.PHONY: docker-build
docker-build: ## Build the docker image
ifeq ($(CI),true)
	docker buildx bake --load --set app.cache-from=type=gha --set app.cache-from=type=registry,ref=$(APP_DOCKER_IMAGE):buildcache --set app.cache-to=type=gha app
else
	docker compose build app
endif

.PHONY: docker-inspect
docker-inspect:
	docker inspect $$(docker compose config --images app)

.PHONY: docker-clean
docker-clean: ## Cleanup containers and persistent volumes
	docker compose down --remove-orphans --volumes
	rm -f .env


##@ Other

.PHONY: setup
setup: ## Setup everything needed for local development
	./bin/setup-host.sh
	$(run) ./bin/setup-container.sh

# Via https://www.thapaliya.com/en/writings/well-documented-makefiles/
# Note: The `##@` comments determine grouping
.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
