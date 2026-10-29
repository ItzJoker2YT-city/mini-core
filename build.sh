#!/usr/bin/env bash
# Experimental rebuild recipe for an x86-64 Debian/Ubuntu Linux build host.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo 'Run with sudo on an x86-64 Debian/Ubuntu build host.' >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo 'Only x86-64 is supported.' >&2; exit 1; }
for c in debootstrap rustc cc sfdisk losetup mkfs.ext4 mkswap grub-install qemu-img zerofree; do
 command -v "$c" >/dev/null || { echo "Missing build dependency: $c" >&2; exit 1; }
done
SOURCE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-"$SOURCE/dist"}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
[ ! -e "$OUT/Mini-Core-x86_64.qcow2" ] || { echo 'Output already exists; choose a new output directory.' >&2; exit 1; }
WORK=$(mktemp -d /var/tmp/mini-core-build.XXXXXX)
LOOP=
cleanup() {
 set +e
 for d in dev/pts dev proc sys ''; do mountpoint -q "$WORK/root/$d" && umount -l "$WORK/root/$d"; done
 [ -z "$LOOP" ] || losetup -d "$LOOP"
 rm -rf "$WORK"
}
trap cleanup EXIT
truncate -s 2G "$WORK/disk.raw"
printf 'label: dos\nunit: sectors\n\nstart=2048,size=3930112,type=83,bootable\nstart=3932160,size=262144,type=82\n' | sfdisk "$WORK/disk.raw"
LOOP=$(losetup --find --show --partscan "$WORK/disk.raw")
mkfs.ext4 -q -L TINY_ROOT "${LOOP}p1"
mkswap -L TINY_SWAP "${LOOP}p2" >/dev/null
mkdir "$WORK/root"; mount "${LOOP}p1" "$WORK/root"; R="$WORK/root"
debootstrap --variant=minbase --arch=amd64 bookworm "$R" https://deb.debian.org/debian
cat > "$R/etc/apt/sources.list" <<'SOURCES'
deb http://deb.debian.org/debian bookworm main
deb http://deb.debian.org/debian bookworm-updates main
deb http://deb.debian.org/debian-security bookworm-security main
SOURCES
# Avoid starting package services on the build host.
printf '#!/bin/sh\nexit 101\n' > "$R/usr/sbin/policy-rc.d"; chmod 755 "$R/usr/sbin/policy-rc.d"
mount --bind /dev "$R/dev"; mount --bind /dev/pts "$R/dev/pts"
mount -t proc proc "$R/proc"; mount -t sysfs sysfs "$R/sys"
cp -L /etc/resolv.conf "$R/etc/resolv.conf"
chroot "$R" /bin/bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y --no-install-recommends linux-image-amd64 initramfs-tools grub-pc-bin grub-common apt sudo openssh-server busybox bash passwd util-linux e2fsprogs kmod curl wget ca-certificates procps iproute2'
sed -i 's@http://@https://@g' "$R/etc/apt/sources.list"
rustc --edition 2021 -C opt-level=z -C panic=abort -C lto -C codegen-units=1 -C relocation-model=static -C link-arg=-nostartfiles -C link-arg=-static -C link-arg=-no-pie "$SOURCE/os/init.rs" -o "$WORK/tiny-init"
install -m755 "$WORK/tiny-init" "$R/usr/sbin/tiny-init"
install -m755 "$SOURCE/os/portable-rc" "$R/etc/rc"
install -m755 "$SOURCE/os/tiny-udhcpc" "$R/etc/tiny-udhcpc"
install -m755 "$SOURCE/os/tiny-account-setup" "$SOURCE/os/tiny-console" "$SOURCE/os/mini-server-name" "$R/usr/local/sbin/"
ln -sfn /bin/busybox "$R/usr/local/bin/cttyhack"
install -m644 "$SOURCE/os/sshd_config" "$R/etc/ssh/sshd_config"
install -m644 "$SOURCE/os/01-mini-console.sh" "$R/etc/profile.d/01-mini-console.sh"
if [ -f "$SOURCE/os/99-tiny-prompt.sh" ]; then install -m644 "$SOURCE/os/99-tiny-prompt.sh" "$R/etc/profile.d/99-tiny-prompt.sh"; fi
printf 'mini-core\n' > "$R/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 mini-core\n::1 localhost ip6-localhost ip6-loopback\n' > "$R/etc/hosts"
cat > "$R/etc/fstab" <<'FSTAB'
LABEL=TINY_ROOT / ext4 defaults 0 1
LABEL=TINY_SWAP none swap sw 0 0
FSTAB
cat > "$R/usr/lib/os-release" <<'RELEASE'
PRETTY_NAME="Mini Core (Debian 12 base)"
NAME="Mini Core"
ID=mini-core
ID_LIKE=debian
VERSION_ID="dev"
DEBIAN_BASE_VERSION_ID="12"
VERSION_CODENAME=bookworm
RELEASE
# Generic initramfs recipe. This is deliberately not bit-identical to the release build.
printf 'MODULES=most\nCOMPRESS=gzip\n' > "$R/etc/initramfs-tools/conf.d/mini-core"
printf 'RESUME=none\n' > "$R/etc/initramfs-tools/conf.d/resume"
install -m644 "$SOURCE/os/grub-defaults" "$R/etc/default/grub"
install -m755 "$SOURCE/os/kernel-update-hook" "$R/etc/kernel/postinst.d/zz-mini-update-grub"
install -m755 "$SOURCE/os/kernel-update-hook" "$R/etc/kernel/postrm.d/zz-mini-update-grub"
chroot "$R" update-initramfs -u -k all
KERNEL=$(find "$R/boot" -maxdepth 1 -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -1)
VERSION=${KERNEL#vmlinuz-}
mkdir -p "$R/boot/grub"
cat > "$R/boot/grub/grub.cfg" <<GRUB
set default=0
set timeout=2
set gfxpayload=text
menuentry 'Mini Core' {
 search --no-floppy --label TINY_ROOT --set=root
 linux /boot/$KERNEL root=LABEL=TINY_ROOT rw rootwait init=/usr/sbin/tiny-init console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0
 initrd /boot/initrd.img-$VERSION
}
GRUB
grub-install --target=i386-pc --boot-directory="$R/boot" "$LOOP"
chroot "$R" passwd -l root >/dev/null
rm -f "$R"/etc/ssh/ssh_host_* "$R/root/.bash_history"
rm -rf "$R/root/.ssh" "$R/var/lib/tiny-setup"
: > "$R/etc/machine-id"
chroot "$R" apt-get clean
mkdir -p "$R/usr/share/doc/mini-core"
install -m644 "$SOURCE/os/init.rs" "$SOURCE/LICENSE" "$R/usr/share/doc/mini-core/"
sync
for d in dev/pts dev proc sys; do umount "$R/$d"; done
umount "$R"
zerofree "${LOOP}p1"
losetup -d "$LOOP"; LOOP=
qemu-img convert -f raw -O qcow2 -c "$WORK/disk.raw" "$OUT/Mini-Core-x86_64.qcow2"
qemu-img check "$OUT/Mini-Core-x86_64.qcow2"
(cd "$OUT" && sha256sum Mini-Core-x86_64.qcow2 > SHA256SUMS.txt)
echo "Built $OUT/Mini-Core-x86_64.qcow2"
