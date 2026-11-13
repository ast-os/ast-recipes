#!/bin/bash
# The live ISO (UEFI, x86_64): the stage as a squashfs, an initramfs that finds the medium and puts a
# tmpfs over the image, GRUB. The system on the medium is the system that gets installed: the live
# settings (no root password, a hostname) are added above the image at boot, not in it.
# Run as: unshare -r --map-auto bootstrap/mkiso.sh      (after mkstage.sh and hosttools.sh)
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
W=$HERE/work
stage=$W/stage; iso=$W/iso; initrd=$W/initrd; efi=$W/efi
out=$W/asteros-live-x86_64.iso
xorriso=$W/host/bin/xorriso
[ -d "$stage" ] || { echo "no $stage: run mkstage.sh first" >&2; exit 1; }
[ -x "$xorriso" ] || { echo "no xorriso: run hosttools.sh first" >&2; exit 1; }
rm -rf "$iso" "$initrd" "$efi"; mkdir -p "$iso"/{boot/grub,live} "$efi"

echo "== kernel"
kernel=$(cd "$stage/boot" && ls vmlinuz-* | head -1)
cp "$stage/boot/$kernel" "$iso/boot/vmlinuz"

echo "== squashfs"
# the kernel and the bootloader files are on the medium itself; the image has them too, as installed
BIND="$stage=/stage-in $iso=/iso-out" "$HERE/bootstrap/chroot.sh" mksquashfs /stage-in /iso-out/live/root.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -no-progress

echo "== initramfs"
mkdir -p "$initrd"/{dev,proc,sys,ro,rw,newroot,medium}
install -m755 "$HERE/orchid/target/x86_64-unknown-linux-musl/release/live-init" "$initrd/init"
(cd "$initrd" && find . | cpio -o -H newc --owner=0:0 --quiet | gzip -9) > "$iso/boot/initrd"

echo "== grub"
cat > "$iso/boot/grub/grub.cfg" <<GRUBCFG
set timeout=3
set default=0
menuentry "asterOS live" {
    linux /boot/vmlinuz quiet console=tty0 console=ttyS0,115200
    initrd /boot/initrd
}
GRUBCFG
cat > "$efi/embed.cfg" <<EMBED
search --no-floppy --file --set=root /live/root.squashfs
set prefix=(\$root)/boot/grub
configfile \$prefix/grub.cfg
EMBED
BIND="$efi=/efi-out" "$HERE/bootstrap/chroot.sh" grub-mkimage -O x86_64-efi -o /efi-out/BOOTX64.EFI -p /boot/grub -c /efi-out/embed.cfg \
    iso9660 part_gpt part_msdos fat search search_fs_file normal linux configfile echo all_video efi_gop gfxterm test cat ls
mkdir -p "$efi/esp/EFI/BOOT"; cp "$efi/BOOTX64.EFI" "$efi/esp/EFI/BOOT/"
truncate -s 16M "$efi/efi.img"; mkfs.vfat -n ASTEREFI "$efi/efi.img" >/dev/null
mcopy -s -i "$efi/efi.img" "$efi/esp/EFI" ::
cp "$HERE/INSTALL.md" "$iso/INSTALL.md"

echo "== iso"
LD_LIBRARY_PATH=$W/host/lib "$xorriso" -as mkisofs -r -V ASTERLIVE -J -joliet-long -iso-level 3 \
    -appended_part_as_gpt -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$efi/efi.img" \
    -e --interval:appended_partition_2:all:: -no-emul-boot -o "$out" "$iso" 2>&1 | grep -v "UPDATE\|WARNING\|^$" || true
echo "$out  $(du -h "$out" | cut -f1)"
