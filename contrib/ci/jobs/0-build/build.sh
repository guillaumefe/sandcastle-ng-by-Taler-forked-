#!/bin/bash
set -exuo pipefail

./sandcastle-build

echo "CI_COMMIT_REF = ${CI_COMMIT_REF}"
mkdir -p /artifacts/sandcastle-ng/${CI_COMMIT_REF} # Variable comes from CI environment
podman tag taler-base-all:latest taler-base-all:${CI_COMMIT_REF}
