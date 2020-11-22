#!/bin/bash

set -e

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
  CONFIG_FILE="etc/terraform.conf"
fi
source "$ROOT_DIR"/"$CONFIG_FILE"

# Install dependencies in host system
apt-get update
apt-get install -y --no-install-recommends ubuntu-keyring ca-certificates \
        debootstrap git binfmt-support parted kpartx rsync dosfstools xz-utils \
        ostree

export PACKAGES="linux-image-${ARCH} grub-pc elementary-minimal elementary-desktop elementary-standard elementary-live"

mkdir -p $BASE_DIR
cd $BASE_DIR

ROOTFS_DIR=$BASE_DIR/rootfs-$ARCH
mkdir -p $ROOTFS_DIR

################################################
### START OF DEB-OSTREE-BUILDER --- PHASE 1
################################################

# Mount cleanup handler
DEVICES_MOUNTED=false
cleanup_mounts()
{
    if $DEVICES_MOUNTED; then
        echo "Unmounting filesystems in $BUILDDIR"
        for dir in dev/pts dev sys proc; do
            umount "$BUILDDIR/$dir"
        done
        DEVICES_MOUNTED=false
    fi
}

# Exit handler
cleanup()
{
    cleanup_mounts || true
}
trap cleanup EXIT

# Ensure that dracut makes generic initramfs instead of looking just
# at the host configuration. This is also in the dracut-config-generic
# package, but that only gets installed after dracut makes the first
# initramfs.
echo "Configuring dracut for generic initramfs"
mkdir -p "$ROOTFS_DIR"/etc/dracut.conf.d
cat > "$ROOTFS_DIR"/etc/dracut.conf.d/90-deb-ostree.conf <<EOF
# Don't make host-specific initramfs
hostonly=no
EOF

# Define a temporary policy-rc.d that ensures that no daemons are
# launched from the installation.
mkdir -p "$ROOTFS_DIR"/usr/sbin
cat > "$ROOTFS_DIR"/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod +x "$ROOTFS_DIR"/usr/sbin/policy-rc.d

# Mount common kernel filesystems. dracut expects /dev to be mounted.
echo "Mounting filesystems in $ROOTFS_DIR"
# DEVICES_MOUNTED=true
# for dir in proc sys dev dev/pts; do
#     mkdir -p "$ROOTFS_DIR/$dir"
#     mount --bind "/$dir" "$ROOTFS_DIR/$dir"
# done

################################################
### END OF DEB-OSTREE-BUILDER --- PHASE 1
################################################

echo "Building system with debootstrap in $ROOTFS_DIR"

debootstrap $BASECODENAME $ROOTFS_DIR "$MIRROR_URL"

# Copy in the elementary PPAs/keys/apt config
for f in ${ROOT_DIR}/etc/config/archives/*.list; do cp -- "$f" "$ROOTFS_DIR/etc/apt/sources.list.d/$(basename -- $f)"; done
for f in ${ROOT_DIR}/etc/config/archives/*.key; do cp -- "$f" "$ROOTFS_DIR/etc/apt/trusted.gpg.d/$(basename -- $f).asc"; done
for f in ${ROOT_DIR}/etc/config/archives/*.pref; do cp -- "$f" "$ROOTFS_DIR/etc/apt/preferences.d/$(basename -- $f)"; done

# Set BASECODENAME/CHANNEL in added repos
sed -i "s/@CHANNEL/$CHANNEL/" $ROOTFS_DIR/etc/apt/sources.list.d/*.list*
sed -i "s/@BASECODENAME/$BASECODENAME/" $ROOTFS_DIR/etc/apt/sources.list.d/*.list*

# Set BASECODENAME in added preferences
sed -i "s/@BASECODENAME/$BASECODENAME/" $ROOTFS_DIR/etc/apt/preferences.d/*.pref*

echo "elementary" > $ROOTFS_DIR/etc/hostname

cat << EOF > elementary-${ARCH}/etc/hosts
127.0.0.1       elementary    localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
# Config to stop flash-kernel trying to detect the hardware in chroot
export FK_MACHINE=none

mount -t proc proc $ROOTFS_DIR/proc
mount -o bind /dev/ $ROOTFS_DIR/dev/
mount -o bind /dev/pts $ROOTFS_DIR/dev/pts

# Make a third stage that installs all of the packages
cat << EOF > $ROOTFS_DIR/third-stage
#!/bin/bash
apt-get update
apt-get --yes upgrade
apt-get --yes install $PACKAGES

rm -f /third-stage
EOF

chmod +x $ROOTFS_DIR/third-stage
LANG=C chroot $ROOTFS_DIR /third-stage

# Copy in any file overrides
cp -r ${ROOT_DIR}/etc/config/includes.chroot/* $ROOTFS_DIR/

mkdir $ROOTFS_DIR/hooks
cp ${ROOT_DIR}/etc/config/hooks/live/*.chroot $ROOTFS_DIR/hooks

for f in $ROOTFS_DIR/hooks/*
do
    base=`basename ${f}`
    LANG=C chroot $ROOTFS_DIR "/hooks/${base}"
done

rm -r "$ROOTFS_DIR/hooks"

# All done with filesystems
cleanup_mounts

# Remove temporary policy-rc.d
rm -f "$ROOTFS_DIR"/usr/sbin/policy-rc.d

echo "Preparing system for OSTree"

REPO=$BASE_DIR/ostree

cd $REPO
ostree init
cd $BASE_DIR

./scripts/deb-ostree-builder.sh $BASECODENAME $REPO -a $ARCH -d $ROOTFS_DIR
