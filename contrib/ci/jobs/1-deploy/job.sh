#!/bin/bash
set -exuo pipefail

ARTIFACT_PATH="/artifacts/sandcastle-ng/${CI_COMMIT_REF}/*.tar"

RSYNC_HOST="taler.host.internal"
RSYNC_PORT=424240
RSYNC_PATH="incoming"
RSYNC_DEST="rsync://${RSYNC_HOST}/${RSYNC_PATH}"


rsync -vP \
      --port ${RSYNC_PORT} \
      ${ARTIFACT_PATH} ${RSYNC_DEST}
