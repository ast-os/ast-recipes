#!/bin/bash
# Run a command inside the new system (work/root): unshare -r --map-auto bootstrap/chroot.sh COMMAND...
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0 COMMAND..." >&2; exit 1; }
mkdir -p "$AST"/{dev,proc,sys,run,sources}
exec unshare --mount --pid --fork --propagation private -- bash -ec '
    mount --rbind /dev "$0/dev"; mount --make-rslave "$0/dev"
    mount -t proc proc "$0/proc"
    mount --rbind /sys "$0/sys"; mount --make-rslave "$0/sys"
    mount -t tmpfs tmpfs "$0/run"
    mount --bind "$1" "$0/sources"
    root=$0; shift
    exec chroot "$root" /usr/bin/env -i HOME=/root TERM="$TERM" PATH=/usr/bin:/usr/sbin LC_ALL=POSIX "$@"
' "$AST" "$SRC" "$@"
