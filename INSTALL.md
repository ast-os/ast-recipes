# Installing asterOS

asterOS is installed by hand, the way Gentoo is: boot the live medium, partition a disk,
unpack the system onto it, chroot into it, configure it, install the bootloader. There is no
installer. x86_64, UEFI only.

The live medium is the system itself: `/medium/live/root.squashfs` is the base system with a
generic kernel, the compiler, `ast` and `git`, and what you boot is that image with a writable
layer over it. Installing it copies it to the disk. The installation needs no network; `ast` does,
to read the repository and to download the sources of what you build.

## 1. Boot the live medium

Write the ISO to a USB stick, or attach it to a virtual machine, and boot it in UEFI mode.

```bash
dd if=asteros-live-x86_64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Log in as `root`; there is no password on the live medium. Check that the firmware booted in
UEFI mode: `ls /sys/firmware/efi` must list files.

## 2. Partition and format

Find the disk with `lsblk` and set it once. Everything below uses these two variables:

```bash
disk=/dev/sda                  # or /dev/nvme0n1, /dev/vda
case $disk in *[0-9]) p=${disk}p ;; *) p=$disk ;; esac
```

A 512 MiB EFI system partition and the rest for the root. This erases the disk.

```bash
sfdisk "$disk" <<TABLE
label: gpt
size=512MiB, type=U
type=L
TABLE
mkfs.vfat -F32 "${p}1"
mkfs.ext4 "${p}2"
```

## 3. Copy the system

```bash
mount "${p}2" /mnt
mkdir -p /mnt/boot/efi
mount "${p}1" /mnt/boot/efi
unsquashfs -f -d /mnt /medium/live/root.squashfs
```

## 4. Configure

`astfstab` prints the fstab lines, by UUID, for everything mounted under a root. `astchroot`
mounts `/proc`, `/sys`, `/dev` and `/run` and enters the root.

```bash
astfstab /mnt >> /mnt/etc/fstab
astchroot /mnt
```

Inside the chroot:

```bash
passwd
echo myhost > /etc/hostname
```

The rest is plain files in `/etc`: `fstab`, `hostname`, `hosts`, `profile`, and the services in
`/etc/orchid/services`. `orchid enable NAME` and `orchid disable NAME` choose what starts at
boot; `orchid list` shows what runs.

## 5. The bootloader

Still inside the chroot:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=asterOS
grub-mkconfig -o /boot/grub/grub.cfg
```

`grub-install` registers a boot entry in the firmware. If the firmware forgets entries (some
do), or for a bootable stick, add `--removable`. `grub-mkconfig` finds the kernels in `/boot`.

The kernel on the image is a generic one. To configure and build your own: `ast -i linux`
builds it from the recipe.

## 6. Reboot

```bash
exit
umount -R /mnt
reboot
```

Remove the live medium. The system starts from the disk.

## Afterwards

```bash
ast -s ""            # every package of the recipes
ast -iy fastfetch    # build one from source and install it
ast -u               # refresh the repository
ast -ua              # upgrade everything
```

Packages are built from source on your machine; binaries are released rarely. The compiler and
the other build tools are part of the system.

Network: `dhcpcd` configures the interfaces by DHCP at boot (`orchid status dhcpcd`). For a fixed
address, `orchid disable dhcpcd` and set it by hand with `ip`, and write the resolver in
`/etc/resolv.conf`.

Rescue: add `rescue` (or `single`) to the kernel command line in GRUB. Only the root file system
and a root shell start.
