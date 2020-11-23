#!/bin/bash

set -e

# Params to workflows.sh.
ENV_FILE="$1"

# check for root permissions
if [[ "$(id -u)" != 0 ]]; then
  echo "E: Requires root permissions" > /dev/stderr
  exit 1
fi

# Install dependencies in host system
apt-get update
apt-get install -y --no-install-recommends ubuntu-keyring ca-certificates \
        debootstrap git binfmt-support parted kpartx rsync dosfstools xz-utils \
        python3.8 python3-pip unzip curl less groff \
        ostree xorriso squashfs-tools

# Install the AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
export AWS_REGION="us-east-1"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Sanity check for the build.
aws help

./build.sh "$ENV_FILE"

# We rsync in reverse data dependence order - the summary and refs
# point to objects + deltas.  Our first pass over the objects doesn't
# perform any deletions, as that would create race conditions.  We
# do handle deletions for refs and summary.

echo "Uploading to AWS S3"

REPO=`pwd`/build/ostree

aws s3 sync "$REPO" "s3://$AWS_S3_BUCKET" --delete --no-progress --acl public-read --follow-symlinks --quiet

# FIXME: Get proper order working below.
# ARGS="--no-progress --acl public-read --follow-symlinks --quiet"

####################################################
# First pass of /objects and /deltas. NO DELETE.
####################################################

# if [[ -f "$REPO/objects" ]]; then
#     aws s3 sync "$REPO/objects" "s3://$AWS_S3_BUCKET/objects"
# fi
# if [[ -f "$REPO/deltas" ]]; then
#     aws s3 sync "$REPO/deltas" "s3://$AWS_S3_BUCKET/deltas"
# fi

####################################################
# Pass of /refs and /summary
####################################################

# if [[ -f "$REPO/refs" ]]; then
#     aws s3 sync "$REPO/refs" "s3://$AWS_S3_BUCKET/refs" --delete $ARGS
# fi
# if [[ -f "$REPO/summary" ]]; then
#     aws s3 sync "$REPO/summary" "s3://$AWS_S3_BUCKET/summary" --delete $ARGS
# fi

####################################################
# Second pass of /objects and /deltas.
####################################################

# if [[ -f "$REPO/objects" ]]; then
#     aws s3 sync "$REPO/objects" "s3://$AWS_S3_BUCKET/objects" --delete $ARGS
# fi
# if [[ -f "$REPO/deltas" ]]; then
#     aws s3 sync "$REPO/deltas" "s3://$AWS_S3_BUCKET/deltas" --delete $ARGS
# fi
