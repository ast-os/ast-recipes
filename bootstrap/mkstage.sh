#!/bin/bash
# The stage archive: the finished base system in work/root as one tarball, to be unpacked into a new
# root by hand (the way a Gentoo stage3 is). Run as: unshare -r --map-auto bootstrap/mkstage.sh
# Leaves work/stage (the tree) and work/asteros-stage-x86_64.tar.xz.
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
orchid=$HERE/orchid/target/x86_64-unknown-linux-musl/release/orchid
astbin=$HERE/ast/target/release
stage=$HERE/work/stage
out=$HERE/work/asteros-stage-x86_64.tar.xz

echo "== the tree"
rm -rf "$stage"; mkdir -p "$stage"
# the toolchain of the bootstrap (tools), the build leftovers and the mounts of the chroot stay behind
tar -C "$AST" --exclude=./tools --exclude=./build --exclude=./sources --exclude=./repo \
    --exclude=./stage3-chroot.sh --exclude=./stage4-chroot.sh --exclude=./var/cache/ast \
    --exclude=./dev --exclude=./proc --exclude=./sys --exclude=./run --exclude=./tmp -cf - . | tar -C "$stage" -xpf -
mkdir -p "$stage"/{dev,proc,sys,run,tmp,boot/efi,boot/grub,mnt,var/cache/ast,var/db/ast}
chmod 1777 "$stage/tmp"
install -m755 "$orchid" "$stage/usr/sbin/orchid"
for l in init reboot poweroff halt; do ln -sf orchid "$stage/usr/sbin/$l"; done
install -m755 "$astbin"/{ast,astpkg,astrap,astfstab,astchroot} "$stage/usr/bin/"

echo "== only the base (what extra.list added to work/root stays out)"
extra=$(grep -v '^#' "$HERE/bootstrap/extra.list" | tr '\n' ' ')
for p in $extra; do "$astbin/ast" --root "$stage" -l 2>/dev/null | grep -q "^$p  " && remove="$remove $p"; done
[ -z "$remove" ] || "$astbin/ast" --root "$stage" -ry $remove >/dev/null

echo "== the recipes (the repository of this system: ast -u reads it)"
rm -rf "$stage/var/db/ast/repo"
"$astbin/astpkg" publish "$HERE/recipes" --no-build --out "$stage/var/db/ast/repo" --name ast --arch x86_64 --channel stable --key "$HERE/work/keys/asteros-dev.key" >/dev/null
sed -i 's|^url = .*|url = "file:///var/db/ast/repo"|' "$stage/etc/ast/repos.toml"
sed -i '/^mirrors/d' "$stage/etc/ast/ast.toml"

echo "== defaults"
echo 'root:*:19000:0:99999:7:::' > "$stage/etc/shadow"; chmod 600 "$stage/etc/shadow"
echo asteros > "$stage/etc/hostname"
: > "$stage/etc/fstab"
printf '# <file system>  <mount point>  <type>  <options>  <dump>  <fsck>\n' > "$stage/etc/fstab"

echo "== archive"
tar -C "$stage" --numeric-owner -cpf - . | xz -T0 -6 > "$out"
echo "$out  $(du -h "$out" | cut -f1)"
