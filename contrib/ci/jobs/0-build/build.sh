#!/bin/bash
set -exuo pipefail

./sandcastle-build

mkdir -p /artifacts/sandcastle-ng/${CI_COMMIT_REF} # Variable comes from CI environment
podman save \
	-o /artifacts/sandcastle-ng/${CI_COMMIT_REF}/taler-base-all.tar \
	taler-base-all:latest
