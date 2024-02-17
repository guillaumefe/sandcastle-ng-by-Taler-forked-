#!/bin/bash
set -exuo pipefail

./sandcastle-build

mkdir -p /artifacts/sandcastle-ng/${CI_COMMIT_REF} # Variable comes from CI environment
podman tag taler-base-all:latest taler-base-all:${CI_COMMIT_REF}
podman save \
	-o /artifacts/sandcastle-ng/${CI_COMMIT_REF}/taler-base-all-${CI_COMMIT_REF}.tar \
	taler-base-all:${CI_COMMIT_REF}
