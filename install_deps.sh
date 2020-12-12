#!/bin/bash

apt-get install -y --no-install-recommends ubuntu-keyring ca-certificates \
        debootstrap git binfmt-support parted kpartx rsync dosfstools xz-utils \
        python3.8 python3-pip unzip curl less groff \
        ostree xorriso squashfs-tools