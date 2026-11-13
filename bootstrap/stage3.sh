#!/bin/bash
# Stage 3: enter the new system and build the tools the final build needs (LFS chapters 7).
# Run it as: unshare -r --map-auto bootstrap/stage3.sh   (a user namespace stands in for root; no sudo)
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
cp "$HERE/bootstrap/stage3-chroot.sh" "$AST/stage3-chroot.sh"
mkdir -p "$AST"/{dev,proc,sys,run,sources,build}
cp /etc/resolv.conf "$AST/etc/resolv.conf" 2>/dev/null || true
exec unshare --mount --pid --fork --propagation private -- bash -ec '
    mount --rbind /dev "$0/dev"; mount --make-rslave "$0/dev"
    mount -t proc proc "$0/proc"
    mount --rbind /sys "$0/sys"; mount --make-rslave "$0/sys"
    mount -t tmpfs tmpfs "$0/run"
    mount --bind "$1" "$0/sources"
    exec chroot "$0" /usr/bin/env -i HOME=/root TERM="$TERM" PATH=/usr/bin:/usr/sbin MAKEFLAGS="$2" LC_ALL=POSIX /bin/bash /stage3-chroot.sh
' "$AST" "$SRC" "$MAKEFLAGS"
