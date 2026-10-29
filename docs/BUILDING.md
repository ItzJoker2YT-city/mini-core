# Building Mini Core

## The tested release

The v0.1.0 disk was assembled from Debian 12 packages, configured with the custom
files in `os/`, given a BIOS GRUB bootloader, and boot-tested in QEMU. Exact binary
and source versions are listed in `manifests/`. The source archives provided with
the release contain the matching Debian package sources and patches.

## Experimental rebuild recipe

Use an x86-64 Debian/Ubuntu Linux machine with root privileges, loop-device support,
and several GiB of free disk space. Do not run unreviewed root scripts on important
systems. The script creates a **new disk file** in its private temporary directory;
it never intentionally formats a physical disk. Review `build.sh` before running it.

Example host dependencies:

```sh
sudo apt update
sudo apt install debootstrap rustc gcc binutils fdisk util-linux e2fsprogs grub-pc-bin grub-common qemu-utils zerofree
sudo ./build.sh ./dist
```

The recipe uses current Debian bookworm repositories and a generic `MODULES=most`
initramfs. Package revisions, kernel version, timestamps and image size can differ
from the published release. It is a functional rebuild recipe, **not** a claim of
bit-reproducible builds. The recipe has shell-syntax checks; a fresh full execution
on every supported build-host version has not been certified.

The custom Rust init can also be compiled separately:

```sh
rustc --edition 2021 -C opt-level=z -C panic=abort -C lto -C codegen-units=1 -C relocation-model=static -C link-arg=-nostartfiles -C link-arg=-static -C link-arg=-no-pie os/init.rs -o tiny-init
```

Rust PID 1 launches `/etc/rc`, then repeatedly starts a controlling-console session.
First-boot setup creates a normal sudo user before SSH is started. Later console
sessions use `/bin/login`; they do not automatically become root.

For Debian package sources, extract a `.dsc` using `dpkg-source -x FILE.dsc`; its
associated upstream/debian tar files must be in the same directory. Rebuilding
those packages requires their declared build dependencies and normal Debian tools.
