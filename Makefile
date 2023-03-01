# Lazily create and "source" the .env file
# See: https://unix.stackexchange.com/a/235254
ifeq (,$(wildcard .env))
$(shell cp .env.example .env)
endif
include .env
export $(shell sed 's/=.*//' .env)

# Always use buildkit
export COMPOSE_DOCKER_CLI_BUILD := 1
export DOCKER_BUILDKIT := 1

.DEFAULT_GOAL := help
SHELL := /bin/bash
APP_SERVICE := app

# Docker compose runs interactively by default, but git hooks run non-interactively.
# Docker will error if there's a mismatch.
# `-t 0` returns true if file descriptor 0 is a terminal (https://stackoverflow.com/a/911213/1582608).
TTY := $(shell [ ! -t 0 ] && echo '--no-TTY ')

# Support running make commands from both host and container.
ifneq ($(RUNNING_IN_CONTAINER),1)
run = docker compose run --rm $(TTY)$(APP_SERVICE)
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

DOCKER_IMAGE := ${APP_REGISTRY}/${APP_NAME}-${APP_TARGET}

.PHONY: docker-build
docker-build: ## Build the docker image
ifeq ($(CI),true)
	docker buildx bake --load --set app.cache-from=type=gha --set app.cache-from=type=registry,ref=$(DOCKER_IMAGE):buildcache --set app.cache-to=type=gha app
else
	docker compose build app
endif

.PHONY: docker-inspect
docker-inspect:
	docker inspect $$(docker compose config --images app)

.PHONY: docker-push
docker-push: ## Push the docker image to the registry
ifeq ($(CI),true)
	docker buildx bake --print --set app.cache-from=type=registry,ref=$(DOCKER_IMAGE):buildcache --set app.cache-to=type=registry,ref=$(DOCKER_IMAGE):buildcache,mode=max --set app.platform=linux/amd64 --set app.platform=linux/arm64 app
else
	docker compose push app
endif

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
