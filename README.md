# Mini Core

**Experimental x86-64 Debian-based command-line VM with a tiny Rust PID 1.**

Mini Core combines Debian 12 userspace and a Debian Linux kernel with a small custom
Rust init and first-boot account setup. It is **not** an all-Rust operating system,
not an Ubuntu replacement, and not the separate Tiny Core Linux distribution.

> **Prototype / prerelease:** not security-audited or production-hardened. The init
> does not implement a full service manager or graceful shutdown/recovery stack.

## Download

Get the QCOW2 disk, checksums and corresponding upstream sources from
[Releases](https://github.com/ItzJoker2YT-city/mini-core/releases). Large disk images are release assets, not Git files.
The v0.1.0 build uses Debian kernel **6.1.0-54-amd64** (package 6.1.190-1).

## Features

- First boot: choose **server name → username → hidden password**.
- Normal administrator account with password-authenticated `sudo` and SSH.
- No root password, test account, test password, SSH host keys, or console access
  key is preconfigured in the public image. SSH starts only after account setup.
- Persistent ext4 root, DHCP, apt, curl, GNU Wget and HTTPS CA certificates.
- A 2 GiB virtual disk with a 128 MiB swap partition.
- Calculator and lighttpd removed; no bundled HTTP app on port 8080.
- Login-shell terminal profile disables software flow-control pauses.

The kernel and Debian utilities are not rewritten in Rust. The custom Rust part
is PID 1. This uses `/etc/rc`, **not systemd**; `systemctl` is unsupported and
arbitrary service packages may need manual integration.

## Boot

Use an x86-64 VM with **legacy BIOS**, not UEFI/Secure Boot. Tested with one CPU,
virtio disk/network, and **128 MiB allocated RAM**. More RAM is recommended for
package installations. The kernel reserves part of that RAM; no zero-resource,
fixed-CPU-percentage, or 90 MB installed-size claim is made.

With a standard QEMU build supporting user-mode networking:

```sh
qemu-system-x86_64 -m 128 -smp 1 -drive file=Mini-Core-v0.1.0-x86_64.qcow2,format=qcow2,if=virtio -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 -device virtio-rng-pci -nographic
```

On Windows, use `qemu-system-x86_64.exe`. Verify `SHA256SUMS.txt` before booting.
Use a separate writable disk copy for every VM. VPS image import and networking
vary by provider; this image has no cloud-init and is not certified on other hosts.

### First boot

1. Open the VM console.
2. Choose a server hostname, or press Enter to keep `mini-core`.
3. Choose a new lowercase username. Existing names such as `root` are rejected.
4. Enter and confirm a non-empty password. **Nothing is displayed while typing.**
5. Log in with the chosen username. The account can use `sudo`.

The root account is not renamed. Root password access is locked. The chosen
hostname is saved in `/etc/hostname` and `/etc/hosts` and persists across reboot.
Hostnames do not automatically register public DNS names.

After setup, using the forwarded port from the example:

```sh
ssh -p 2222 YOUR_USERNAME@127.0.0.1
sudo apt update
sudo -i
```

Change your own password with `passwd`. Change the hostname later with
`sudo mini-server-name`. Open a new shell to refresh an existing prompt.
SSH's `AllowUsers` setting initially permits only the chosen account; update it
when deliberately adding other SSH users. Prefer SSH keys and appropriate firewall
controls before any public exposure.

### Shutdown

Save your work and close extra sessions, then:

```sh
sudo sync
sudo mount -o remount,ro /
sudo /bin/busybox poweroff -f
```

This simple init does not provide coordinated service shutdown. Keep backups.

## Build and source

- Custom init and boot/account configuration: [`os/`](os/).
- Experimental rebuild recipe: [`build.sh`](build.sh).
- Build instructions and limitations: [`docs/BUILDING.md`](docs/BUILDING.md).
- Public-release test report: [`docs/TESTING.md`](docs/TESTING.md).
- Exact release package/source versions: [`manifests/`](manifests/).

The rebuild recipe installs current bookworm packages; it is **not a bit-for-bit
reproduction guarantee** for this release. The release QCOW2 is separately tested.

## Licensing

The MIT license in this repository applies to the **custom Mini Core code**, not
to Debian, Linux, GRUB, BusyBox, GNU tools, or other upstream components.
Original package copyright/license notices remain under `/usr/share/doc` in the
image. The release includes matching upstream source archives (including Debian
patches) for the installed binary packages and their declared Built-Using sources.
See [`docs/LICENSING.md`](docs/LICENSING.md).

No temporary sshx/Pinggy URL, user-configured VM, login password, private SSH key,
or GitHub credential is part of the public release.
