#!/bin/bash

set -e

# Params to workflows.sh.
CONFIG_FILE="$1"

# check for root permissions
if [[ "$(id -u)" != 0 ]]; then
  echo "E: Requires root permissions" > /dev/stderr
  exit 1
fi

# Install dependencies in host system
apt-get update
apt-get install -y --no-install-recommends ubuntu-keyring ca-certificates \
        debootstrap git binfmt-support parted kpartx rsync dosfstools xz-utils \
        ostree

# Install the AWS CLI
export AWS_REGION="us-east-1"
python -m pip install --user awscli

./build.sh "$CONFIG_FILE"

# We rsync in reverse data dependence order - the summary and refs
# point to objects + deltas.  Our first pass over the objects doesn't
# perform any deletions, as that would create race conditions.  We
# do handle deletions for refs and summary.

REPO=`pwd`/build/ostree
ARGS="--no-progress --acl public-read --follow-symlinks --quiet"

# First pass of /objects and /deltas. NO DELETE.
if [[ -f "$REPO/objects" ]]; then
    aws s3 sync "$REPO/objects" "s3://$AWS_S3_BUCKET/objects"
fi
if [[ -f "$REPO/deltas" ]]; then
    aws s3 sync "$REPO/deltas" "s3://$AWS_S3_BUCKET/deltas"
fi

# Pass of /refs and /summary
if [[ -f "$REPO/refs" ]]; then
    aws s3 sync "$REPO/refs" "s3://$AWS_S3_BUCKET/refs" --delete $ARGS
fi
if [[ -f "$REPO/summary" ]]; then
    aws s3 sync "$REPO/summary" "s3://$AWS_S3_BUCKET/summary" --delete $ARGS
fi

# Second pass of /objects and /deltas.
if [[ -f "$REPO/objects" ]]; then
    aws s3 sync "$REPO/objects" "s3://$AWS_S3_BUCKET/objects" --delete $ARGS
fi
if [[ -f "$REPO/deltas" ]]; then
    aws s3 sync "$REPO/deltas" "s3://$AWS_S3_BUCKET/deltas" --delete $ARGS
fi
