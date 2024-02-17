#!/bin/bash
set -exuo pipefail

./contrib/ci/jobs/1-build-head/update-tags.sh

./sandcastle-build

mkdir -p /artifacts/sandcastle-ng/${CI_COMMIT_REF} # Variable comes from CI environment
podman tag taler-base-all:latest taler-base-all-head:latest
podman tag taler-base-all-head:latest taler-base-all-head:${CI_COMMIT_REF}
podman save \
	-o /artifacts/sandcastle-ng/${CI_COMMIT_REF}/taler-base-all-head.tar \
	taler-base-all-head:latest
