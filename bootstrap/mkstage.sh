#!/bin/bash
# The stage: the finished base system in work/root as a tree (work/stage) and one tarball, to be
# unpacked into a new root the way a Gentoo stage3 is. Run as: unshare -r --map-auto bootstrap/mkstage.sh
# Everything in it came from a package of base.list; the bootstrap leaves behind its toolchain
# (tools), its build directories and the mounts of the chroot.
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
stage=$HERE/work/stage
out=$HERE/work/asteros-stage-x86_64.tar.xz

echo "== the tree"
rm -rf "$stage"; mkdir -p "$stage"
tar -C "$AST" --exclude=./tools --exclude=./build --exclude=./sources --exclude=./repo \
    --exclude=./etc/ast-bootstrap --exclude=./etc/resolv.conf --exclude=./stage3-chroot.sh --exclude=./stage4-chroot.sh --exclude=./var/cache/ast \
    --exclude=./dev --exclude=./proc --exclude=./sys --exclude=./run --exclude=./tmp -cf - . | tar -C "$stage" -xpf -
mkdir -p "$stage"/{dev,proc,sys,run,tmp,boot/efi,mnt,var/cache/ast}
chmod 1777 "$stage/tmp"

echo "== the accounts: root has no password until the installer sets one"
echo 'root:*:19000:0:99999:7:::' > "$stage/etc/shadow"; chmod 600 "$stage/etc/shadow"

echo "== archive"
tar -C "$stage" --numeric-owner -cpf - . | xz -T0 -6 > "$out"
echo "$out  $(du -h "$out" | cut -f1)"
