#!/bin/bash
set -exuo pipefail

for i in buildconfig/*.tag ; do
	echo "master" > "$i"
done

./sandcastle-build

mkdir -p /artifacts/sandcastle-ng/${CI_COMMIT_REF} # Variable comes from CI environment
podman tag taler-base-all:latest taler-base-all-head:latest
podman tag taler-base-head:latest taler-base-all-head:${CI_COMMIT_REF}
podman save \
	-o /artifacts/sandcastle-ng/${CI_COMMIT_REF}/taler-base-all-head.tar \
	taler-base-all-head:latest
