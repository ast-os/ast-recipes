# Installing asterOS

asterOS is installed by hand, the way Gentoo is: boot the live medium, partition a disk,
unpack the stage archive, chroot into it, configure it, install the bootloader. There is no
installer. x86_64, UEFI only.

The live medium holds the stage archive (`/medium/live/asteros-stage-x86_64.tar.xz`): the
base system with the kernel, `ast` and the recipes of this release. Nothing needs a network
until you install packages.

## 1. Boot the live medium

Write the ISO to a USB stick (`dd if=asteros-live-x86_64.iso of=/dev/sdX bs=4M status=progress`)
or attach it to a virtual machine, and boot it in UEFI mode. Log in as `root`, there is no password.
Check that the firmware booted in UEFI mode: `ls /sys/firmware/efi` must show files.

## 2. Partition and format

Below the disk is `/dev/sda` (`lsblk` shows yours): a 512 MiB EFI system partition and the rest
for the root.

```bash
sfdisk /dev/sda <<TABLE
label: gpt
size=512MiB, type=U
type=L
TABLE
mkfs.vfat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
```

## 3. Unpack the stage

```bash
mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
tar xpf /medium/live/asteros-stage-x86_64.tar.xz -C /mnt --numeric-owner
```

## 4. Configure

`astfstab` prints the fstab lines for what is mounted under a root; `astchroot` enters it.

```bash
astfstab /mnt >> /mnt/etc/fstab
astchroot /mnt
```

Inside the chroot:

```bash
passwd                         # root has no password yet
echo myhost > /etc/hostname
```

Everything else is a file in `/etc`: `fstab`, `hostname`, `hosts`, `profile`, the services in
`/etc/orchid/services`. `orchid enable NAME` and `orchid disable NAME` choose what starts at boot.

## 5. The bootloader

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=asterOS
grub-mkconfig -o /boot/grub/grub.cfg
```

Add `--removable` to `grub-install` for a stick or a firmware that forgets boot entries.
`grub-mkconfig` finds the kernels in `/boot`. The kernel in the stage is a generic one; to
configure and build your own, `ast -i linux` builds it from the recipe.

## 6. Reboot

```bash
exit
umount -R /mnt
reboot
```

## Afterwards

```bash
ast -s ""          # all the packages of the recipes
ast -iy fastfetch  # build and install one from source
ast -u             # refresh the repository
ast -ua            # upgrade everything
```

Packages are built from source on your machine; binaries are rare. The base system's own
build tools (compiler, `make`, ...) are in the stage.
