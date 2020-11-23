#!/bin/bash -e

# deb-ostree-builder - Build bootable Debian OSTree commits
#
# Copyright (C) 2017  Dan Nicholson <nicholson@endlessm.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

PROG=$(readlink -f "$0")
PROGDIR=$(dirname "$PROG")

# Defaults
ARCH=$(dpkg --print-architecture)
BUILDDIR=
GPG_SIGN=()
GPG_HOMEDIR=

usage() {
    cat <<EOF
Usage: $0 [OPTION...] BASECODENAME REPO

  -a, --arch		build architecture
  -d, --dir		build directory
  --gpg-sign		GPG key ID to use for signing
  --gpg-homedir		GPG homedir to find keys
  -h, --help		show this message and exit

deb-ostree-builder constructs a Debian OS for use as a bootable
OSTree. It uses debootstrap to construct the OS, adjusts it to be
compatible with OSTree, and then commits it to a repository.

REPO is the path the the OSTree repository
where the commit will be made.
EOF
}

ARGS=$(getopt -n "$0" \
	      -o a:d:h \
	      -l arch:,dir:,gpg-sign:,gpg-homedir:,help \
	      -- "$@")
eval set -- "$ARGS"

while true; do
    case "$1" in
	-a|--arch)
	    ARCH=$2
	    shift 2
	    ;;
        -d|--dir)
            BUILDDIR=$2
            shift 2
            ;;
	--gpg-sign)
	    GPG_SIGN+=($2)
	    shift 2
	    ;;
	--gpg-homedir)
	    GPG_HOMEDIR=$2
	    shift 2
	    ;;
	-h|--help)
	    usage
	    exit 0
	    ;;
	--)
	    shift
	    break
	    ;;
    esac
done

if [ $# -lt 2 ]; then
    echo "Must specify BASECODENAME and REPO" >&2
    exit 1
fi

BASECODENAME=$1
REPO=$2

# Remove dbus machine ID cache (makes each system unique)
rm -f "$BUILDDIR"/var/lib/dbus/machine-id "$BUILDDIR"/etc/machine-id

# Remove resolv.conf copied from the host by debootstrap. The settings
# are only valid on the target host and will be populated at runtime.
rm -f "$BUILDDIR"/etc/resolv.conf

# OSTree uses a single checksum of the combined kernel and initramfs
# to manage boot. Determine the checksum and rename the files the way
# OSTree expects.
echo "Renaming kernel and initramfs per OSTree requirements"
pushd "$BUILDDIR"/boot >/dev/null

vmlinuz_match=(vmlinuz*)
vmlinuz_file=${vmlinuz_match[0]}
initrd_match=(initrd.img* initramfs*)
initrd_file=${initrd_match[0]}

csum=$(cat ${vmlinuz_file} ${initrd_file} | \
	      sha256sum --binary | \
	      awk '{print $1}')
echo "OSTree boot checksum: ${csum}"

mv ${vmlinuz_file} ${vmlinuz_file}-${csum}
mv ${initrd_file} ${initrd_file/initrd.img/initramfs}-${csum}

popd >/dev/null

# OSTree only commits files or symlinks
rm -rf "$BUILDDIR"/dev
mkdir -p "$BUILDDIR"/dev

# Fixup home directory base paths for OSTree
sed -i -e 's|DHOME=/home|DHOME=/sysroot/home|g' \
    "${BUILDDIR}"/etc/adduser.conf
sed -i -e 's|# HOME=/home|HOME=/sysroot/home|g' \
    "${BUILDDIR}"/etc/default/useradd

# Move /etc to /usr/etc.
#
# FIXME: Need to handle passwd and group to be updatable. This can be
# done with libnss-altfiles, though that has other drawbacks.
if [ -d "${BUILDDIR}"/usr/etc ]; then
    echo "ERROR: Non-empty /usr/etc found!" >&2
    ls -lR "${BUILDDIR}"/usr/etc
    exit 1
fi
mv "${BUILDDIR}"/etc "${BUILDDIR}"/usr

# Move dpkg database to /usr so it's accessible after the OS /var is
# mounted, but make a symlink so it works without modifications to dpkg
# or apt
mkdir -p "${BUILDDIR}"/usr/share/dpkg
if [ -e "${BUILDDIR}"/usr/share/dpkg/database ]; then
    echo "ERROR: /usr/share/dpkg/database already exists!" >&2
    ls -lR "${BUILDDIR}"/usr/share/dpkg/database >&2
    exit 1
fi
mv "${BUILDDIR}"/var/lib/dpkg "${BUILDDIR}"/usr/share/dpkg/database
ln -sr "${BUILDDIR}"/usr/share/dpkg/database \
   "${BUILDDIR}"/var/lib/dpkg

# tmpfiles.d setup to make the ostree root compatible with persistent
# directories in the sysroot.
cat > "${BUILDDIR}"/usr/lib/tmpfiles.d/ostree.conf <<EOF
d /sysroot/home 0755 root root -
d /sysroot/root 0700 root root -
d /var/opt 0755 root root -
d /var/local 0755 root root -
d /run/media 0755 root root -
L /var/lib/dpkg - - - - ../../usr/share/dpkg/database
EOF

# Create symlinks in the ostree for persistent directories.
mkdir -p "${BUILDDIR}"/sysroot
rm -rf "${BUILDDIR}"/{home,root,media,opt} "${BUILDDIR}"/usr/local
ln -s /sysroot/ostree "${BUILDDIR}"/ostree
ln -s /sysroot/home "${BUILDDIR}"/home
ln -s /sysroot/root "${BUILDDIR}"/root
ln -s /var/opt "${BUILDDIR}"/opt
ln -s /var/local "${BUILDDIR}"/usr/local
ln -s /run/media "${BUILDDIR}"/media

# Now ready to commit. Make the repo if necessary. An archive-z2 repo
# is used since the intention is to use this repo to serve updates
# from.
mkdir -p "$REPO"
if [ ! -f "$REPO"/config ]; then
    echo "Initialiazing OSTree repo $REPO"
    ostree --repo="$REPO" init --mode=archive-z2
fi

# Make the commit. The ostree ref is flatpak style.
branch="os/bloom/$ARCH/$BASECODENAME"
COMMIT_OPTS=(
    --repo="$REPO"
    --branch="$branch"
    --subject="Build $BASECODENAME $ARCH $(date --iso-8601=seconds)"
    --skip-if-unchanged
    --table-output
)
for id in ${GPG_SIGN[@]}; do
    COMMIT_OPTS+=(--gpg-sign="$id")
done
if [ -n "$GPG_HOMEDIR" ]; then
    COMMIT_OPTS+=(--gpg-homedir="$GPG_HOMEDIR")
fi
echo "Committing $BUILDDIR to $REPO branch $branch"
ostree commit "${COMMIT_OPTS[@]}" "$BUILDDIR"

# Update the repo summary
SUMMARY_OPTS=(
    --repo="$REPO"
    --update
)
for id in ${GPG_SIGN[@]}; do
    SUMMARY_OPTS+=(--gpg-sign="$id")
done
if [ -n "$GPG_HOMEDIR" ]; then
    SUMMARY_OPTS+=(--gpg-homedir="$GPG_HOMEDIR")
fi
echo "Updating $REPO summary file"
ostree summary "${SUMMARY_OPTS[@]}"