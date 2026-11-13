#!/bin/bash
# A bootable UEFI test disk from the finished system in work/root: GPT, an ESP with GRUB, an ext4 root.
# Run as: unshare -r --map-auto bootstrap/mkdisk.sh OUT.img      (EMPTY_ROOT_PASSWORD=1: root has no password, for tests)
set -e
. "$(dirname "$0")/env.sh"
out=$(realpath -m "${1:?usage: mkdisk.sh OUT.img}")
orchid=$HERE/orchid/target/x86_64-unknown-linux-musl/release/orchid
work=$(mktemp -d "$HERE/work/disk.XXXXXX"); trap 'rm -rf "$work"' EXIT
esp_id=$(uuidgen); root_id=$(uuidgen); fs_uuid=$(uuidgen)

echo "== the system"
stage=$work/root
cp -a --reflink=auto "$AST" "$stage"
rm -rf "$stage"/{repo,sources,build,stage3-chroot.sh,stage4-chroot.sh} "$stage"/var/cache/ast/* "$stage"/dev/* "$stage"/proc/* "$stage"/sys/* "$stage"/run/* "$stage"/tmp/*
mkdir -p "$stage"/{repo,sources,build,boot/efi,boot/grub}
install -m755 "$orchid" "$stage/usr/sbin/orchid"
for l in init reboot poweroff halt; do ln -sf orchid "$stage/usr/sbin/$l"; done
echo asteros > "$stage/etc/hostname"
if [ -n "${EMPTY_ROOT_PASSWORD:-}" ]; then echo 'root::19000:0:99999:7:::' > "$stage/etc/shadow"; chmod 600 "$stage/etc/shadow"; fi
cat > "$stage/etc/fstab" <<FSTAB
PARTUUID=$root_id  /          ext4  rw,relatime  0  1
PARTUUID=$esp_id   /boot/efi  vfat  rw,umask=0077  0  2
FSTAB
kernel=$(cd "$stage/boot" && ls vmlinuz-* | head -1)
cat > "$stage/boot/grub/grub.cfg" <<GRUBCFG
set timeout=3
set default=0
menuentry "asterOS" {
    linux /boot/$kernel root=PARTUUID=$root_id rw init=/sbin/init console=tty0 console=ttyS0,115200 panic=10
}
GRUBCFG

echo "== grub"
cat > "$stage/tmp/embed.cfg" <<EMBED
search --no-floppy --fs-uuid --set=root $fs_uuid
set prefix=(\$root)/boot/grub
configfile \$prefix/grub.cfg
EMBED
chroot "$stage" /usr/bin/grub-mkimage -O x86_64-efi -o /tmp/grubx64.efi -p /boot/grub -c /tmp/embed.cfg \
    part_gpt part_msdos fat ext2 normal search search_fs_uuid search_fs_file linux configfile echo all_video efi_gop efi_uga gfxterm test
mkdir -p "$work/esp/EFI/BOOT"; cp "$stage/tmp/grubx64.efi" "$work/esp/EFI/BOOT/BOOTX64.EFI"; rm -f "$stage/tmp/"*
truncate -s 256M "$work/esp.img"; mkfs.vfat -F32 -n ASTERESP "$work/esp.img" >/dev/null
mcopy -s -i "$work/esp.img" "$work/esp/EFI" ::

echo "== disk"
size=$(du -sm "$stage" | cut -f1); size=$((size * 12 / 10 + 512))
truncate -s "${size}M" "$work/root.img"
mkfs.ext4 -q -F -L asteros -U "$fs_uuid" -d "$stage" "$work/root.img"
truncate -s "$((size + 256 + 4))M" "$out"
sfdisk -q "$out" <<TABLE
label: gpt
start=1MiB, size=256MiB, type=U, uuid=$esp_id
type=L, uuid=$root_id
TABLE
dd if="$work/esp.img" of="$out" bs=1M seek=1 conv=notrunc status=none
dd if="$work/root.img" of="$out" bs=1M seek=257 conv=notrunc status=none
echo "$out  $(du -h "$out" | cut -f1)"
