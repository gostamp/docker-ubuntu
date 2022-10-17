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


##@ App

.PHONY: build
build: docker-build

.PHONY: lint
lint: ## Lint and format files
	./bin/run-in-container.sh ./bin/lint.sh

.PHONY: run
run: ## Run the container
	./bin/run-in-container.sh ./bin/command.sh

.PHONY: shell
shell: ## Shell into the container
	./bin/run-in-container.sh bash

.PHONY: test
test: APP_ENV := test
test: ## Test the container
	./bin/run-in-container.sh ./bin/test.sh


##@ Docker

.PHONY: docker-build
docker-build: ## Build the docker image
	docker-compose build app

.PHONY: docker-pull
docker-pull: ## Pull the docker image from the registry
	docker-compose pull app

.PHONY: docker-push
docker-push: ## Push the docker image to the registry
	docker-compose push app

.PHONY: docker-clean
docker-clean: ## Cleanup containers and persistent volumes
	docker-compose down -v
	rm -f .env


##@ Other

.PHONY: setup
setup: ## Setup everything needed for local development
# editorconfig-checker-disable
	@if command -v docker-compose >/dev/null 2>&1; then echo "Found docker-compose"; else echo "Unable to find docker-compose!"; exit 1; fi
# editorconfig-checker-enable
	mkdir -p ~/.sops && touch ~/.sops/sops-age-key.txt && chmod 0600 ~/.sops/sops-age-key.txt
	@echo "Building..." && echo "" && $(MAKE) docker-build

# Via https://www.thapaliya.com/en/writings/well-documented-makefiles/
# Note: The `##@` comments determine grouping
.PHONY: help
help: ## Display this help
# editorconfig-checker-disable
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
# editorconfig-checker-enable
	@echo ""
