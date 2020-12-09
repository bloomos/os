#!/bin/bash -e

# deploy_ostree_local.sh:
#
# Should be run AFTER build.sh.

# check for root permissions
if [[ "$(id -u)" != 0 ]]; then
  echo "E: Requires root permissions" > /dev/stderr
  exit 1
fi

ROOT_DIR=`pwd`
BASE_DIR=`pwd`/build

# get config
if [ -n "$1" ]; then
  CONFIG_FILE="$1"
else
  CONFIG_FILE=".env"
fi
source "$ROOT_DIR"/"$CONFIG_FILE"

REPO=$BASE_DIR/ostree
BRANCH="os/bloom/$ARCH/$BASECODENAME"

ostree pull-local --disable-fsync $REPO
ostree admin deploy --karg=rw --karg=splash \
    --karg=plymouth.ignore-serial-consoles --karg=quiet \
    $BRANCH

# show status at end
ostree admin status