<div align="center">
  <h1 align="center"><center>Bloom OS</center></h1>
  <h3 align="center"><center>Build scripts for OSTree creation</center></h3>
  <br>
  <br>
</div>

---

Experiments with Linux distributions. Right now, the state of the project is an `elementary OS`-ish system running from OSTree, which has the following benefits:

* Read-only system.
* A/B updates like Android.
* Separating system packages from user packages.

In the future, my main goal is to work on the application stack in Bloom, things like:

* Wayland
* Unique and friendly windowing system
* Flutter as primary toolkit
* *'Just works'* mentality.
* Productive environment for software developers and creatives.

I am doing this only as a hobby, so I want to reuse from other free software projects when possible.

## Installing

Currently there's no way to install directly. What I recommend is installing [Endless OS](https://endlessos.com/home/), then 'deploy' the OSTree you've built since Endless also uses OSTree.

The `deploy_ostree_local.sh` should do this. This is what I currently do for my system (developing Bloom on Bloom!).

## Building Locally

Make sure you're on a Debian/Ubuntu derived system, download all dependencies:

```sh
apt-get update
apt-get install -y --no-install-recommends ubuntu-keyring ca-certificates \
        debootstrap git binfmt-support parted kpartx rsync dosfstools xz-utils \
        python3.8 python3-pip unzip curl less groff \
        ostree xorriso squashfs-tools
```

Then run `sudo ./build.sh`. This will create a OSTree repository in the `build/ostree` directory that you can (a) deploy to system (b) sync with S3.

## Credits

Bloom would not be possible without the work of the open-source community, which I hope this project eventually contributes back to.

A non-exaustive list of projects Bloom wouldn't be possible without:

- elementary OS
- Ubuntu
- [deb-ostree-builder](https://github.com/dbnicholson/deb-ostree-builder)
- Purism and `phosh` Wayland shell

### Hosting

Hosting for our APT repository generously hosted by [Cloudsmith](https://cloudsmith.com/).

![Cloudsmith Logo](assets/cloudsmith-logo-color.png)