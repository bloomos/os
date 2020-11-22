<div align="center">
  <a href="https://elementary.io" align="center">
    <center align="center">
      <img src="https://raw.githubusercontent.com/elementary/brand/master/logomark-black.png" alt="elementary" align="center">
    </center>
  </a>
  <br>
  <h1 align="center"><center>elementary OS</center></h1>
  <h3 align="center"><center>Build scripts for image creation</center></h3>
  <br>
  <br>
</div>

---

Experiments with Linux-based distributions. Right now, the goal is to get an elementary OS ish system running from OSTree, which has the following benefits:

* Read-only system.
* A/B updates like Android.

I am doing this only as a hobby, so I want to reuse from other free software projects when possible. With that in mind...

- [dbnicholson/deb-ostree-builder](https://github.com/dbnicholson/deb-ostree-builder/tree/simple-builder) - this looks interesting, want to inline the scripts and change to use `debootstrap` (like Elementary for Pi does?).
- [archlinux/archiso](https://gitlab.archlinux.org/archlinux/archiso/-/blob/master/archiso/mkarchiso) - the Bash scripts here look great, and would be useful for making a live ISO from SquashFS.

To-Do List:

* [ ] Integrate deb-ostree-builder scripts, get it to run w/ `debootstrap` without crashing.
* [ ] Work with `archlinux/archiso` to get a live ISO created from OSTree.
* [ ] Be able to install an OSTree system.

---

## Building Locally

As elementary OS is built with the Debian version of `live-build`, not the Ubuntu patched version, it's easiest to build an elementary .iso in a Debian VM or container. This prevents messing up your host system too.

The following example uses Docker and assumes you have Docker correctly installed and set up:

 1) Clone this project & `cd` into it:

    ```
    git clone https://github.com/elementary/os && cd os
    ```

 2) Configure the channel in the `etc/terraform.conf` (stable, daily).

 3) Run the build:

    ```
    docker run --privileged -i -v /proc:/proc \
        -v ${PWD}:/working_dir \
        -w /working_dir \
        debian:latest \
        /bin/bash -s etc/terraform.conf < build.sh
    ```

 4) When done, your image will be in the `builds` folder.

## Further Information

More information about the concepts behind `live-build` and the technical decisions made to arrive at this set of tools to build an .iso can be found [on the wiki](https://github.com/elementary/os/wiki/Building-iso-Images).
