#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"


echo " => Linting: hadolint"
hadolint ./Dockerfile
