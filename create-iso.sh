#!/bin/bash -e

BASE_DIR=`pwd`/build
REPO=$BASE_DIR/ostree

SYSROOT=$BASE_DIR/sysroot
SYSROOT_REPO=$SYSROOT/ostree/repo
SYSROOT_BOOT=$SYSROOT/boot

# $ARCH and $BASECODENAME from .env
BRANCH="os/bloom/$ARCH/$BASECODENAME"

mkdir -p $REPO

#############################################################
# Init OSTree filesystem with a checkout of our tree.
#############################################################

# $NAME, $REMOTE_OSTREE_REPO from .env

ostree admin init-fs "$SYSROOT"
ostree admin --sysroot="$SYSROOT" os-init "$NAME"
ostree --repo="$SYSROOT_REPO" remote add "$NAME" "$REMOTE_OSTREE_REPO" "$BRANCH"
ostree --repo="$SYSROOT_REPO" pull-local --disable-fsync --remote="$NAME" "$REPO" "$BRANCH"

#############################################################
# Basic bootloader setup, assume GRUB (for now).
#############################################################

mkdir -p "$SYSROOT_BOOT"/grub
# This is entirely using Boot Loader Spec (bls). A more general
# grub.cfg is likely needed
cat > "${BOOT}"/grub/grub.cfg <<"EOF"
insmod blscfg
bls_import
set default='0'
EOF
fi

#############################################################
# Deploy our OSTree into the file system for next reboot.
#############################################################

# $NAME from .env
# Deploy with root=UUID random

KARGS=(--karg=root=UUID=$(uuidgen) --karg=rw --karg=splash \
    --karg=plymouth.ignore-serial-consoles --karg=quiet)

ostree admin --sysroot="$SYSROOT" deploy --os="$NAME" "${KARGS[@]}" "$NAME:$BRANCH"

# Now $SYSROOT is ready to be written to some disk

#############################################################
# Make SquashFS filesystem and bootable ISO.
#############################################################

SQUASHFS=$BASE_DIR/image.sfs

mksquashfs "$SYSROOT" "$SQUASHFS" -noappend -comp xz

