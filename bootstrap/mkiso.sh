#!/bin/bash
# The live ISO (UEFI, x86_64): the system without the toolchain on a squashfs, an initramfs that finds
# the medium and puts a tmpfs over it, GRUB, and the stage archive to install from.
# Run as: unshare -r --map-auto bootstrap/mkiso.sh      (after mkstage.sh)
# Needs squashfs-tools and libisoburn installed in work/root (extra.list).
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
W=$HERE/work
stage=$W/stage; live=$W/live; iso=$W/iso; initrd=$W/initrd; efi=$W/efi
out=$W/asteros-live-x86_64.iso
[ -d "$stage" ] || { echo "no $stage: run mkstage.sh first" >&2; exit 1; }
rm -rf "$live" "$iso" "$initrd" "$efi"; mkdir -p "$live" "$iso"/{boot/grub,live} "$efi"

echo "== the live system"
tar -C "$stage" -cf - . | tar -C "$live" -xpf -
# no compilers on the medium: a live system installs, it does not build
rm -rf "$live"/usr/include "$live"/usr/lib/gcc "$live"/usr/libexec/gcc "$live"/usr/lib/perl5 "$live"/usr/lib/python3* \
    "$live"/usr/share/{doc,man,info,gtk-doc,perl5} "$live"/usr/lib/*.a "$live"/usr/lib/cmake "$live"/var/db/ast/repo
for b in gcc g++ cc c++ cpp gcov gcov-dump gcov-tool lto-dump gcc-ar gcc-nm gcc-ranlib ld ld.bfd ld.gold as ar nm objdump objcopy \
    ranlib readelf strip size strings gprof addr2line c++filt elfedit perl python3 pydoc3 meson ninja; do
    rm -f "$live/usr/bin/$b" "$live/usr/bin/$AST_TGT-$b" "$live/usr/bin/x86_64-pc-linux-gnu-$b"
done
rm -f "$live"/usr/bin/perl[0-9]* "$live"/usr/bin/python3.* "$live"/usr/bin/x86_64-*
kernel=$(cd "$live/boot" && ls vmlinuz-* | head -1)
cp "$live/boot/$kernel" "$iso/boot/vmlinuz"
rm -rf "$live"/boot/*; mkdir -p "$live/boot"
echo asteros-live > "$live/etc/hostname"
echo 'root::19000:0:99999:7:::' > "$live/etc/shadow"; chmod 600 "$live/etc/shadow"
cp "$HERE/INSTALL.md" "$live/root/INSTALL.md"
printf 'asterOS live \\r (\\l)\n\nroot has no password here. The guide: less /root/INSTALL.md\n\n' > "$live/etc/issue"

echo "== squashfs"
BIND="$live=/live-src $iso=/iso-out" "$HERE/bootstrap/chroot.sh" mksquashfs /live-src /iso-out/live/root.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -no-progress

echo "== initramfs"
mkdir -p "$initrd"/{dev,proc,sys,ro,rw,newroot,medium}
install -m755 "$HERE/orchid/target/x86_64-unknown-linux-musl/release/live-init" "$initrd/init"
(cd "$initrd" && find . | cpio -o -H newc --owner=0:0 --quiet | gzip -9) > "$iso/boot/initrd"

echo "== grub"
cat > "$iso/boot/grub/grub.cfg" <<GRUBCFG
set timeout=3
set default=0
menuentry "asterOS live" {
    linux /boot/vmlinuz console=tty0 console=ttyS0,115200
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

echo "== the stage archive"
cp "$W/asteros-stage-x86_64.tar.xz" "$iso/live/"
cp "$HERE/INSTALL.md" "$iso/INSTALL.md"

echo "== iso"
BIND="$iso=/iso-in $efi=/efi-in $W=/out" "$HERE/bootstrap/chroot.sh" xorriso -as mkisofs -r -V ASTERLIVE -J -joliet-long -iso-level 3 \
    -appended_part_as_gpt -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B /efi-in/efi.img \
    -e --interval:appended_partition_2:all:: -no-emul-boot -o /out/asteros-live-x86_64.iso /iso-in
echo "$out  $(du -h "$out" | cut -f1)"
