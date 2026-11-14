#!/bin/bash
# Stage 4: build the base system with ast, from the recipes, inside the new system.
# Run it as: unshare -r --map-auto bootstrap/stage4.sh [PACKAGE...]   (default: everything in base.list)
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
ASTBIN=$HERE/ast/target/release
KEY=${ASTEROS_KEY:-$HOME/.config/asteros-keys/asteros}   # the release key (secret part: keep it offline)

# ast itself, the recipes as a repository, its configuration, the sources as a mirror
install -m755 "$ASTBIN/ast" "$ASTBIN/astpkg" "$AST/usr/bin/"
rm -rf "$AST/repo"; cp -a "$HERE/recipes" "$AST/repo"
"$ASTBIN/astpkg" index "$AST/repo" --name ast --arch x86_64 --channel stable --key "$KEY.key" >/dev/null
mkdir -p "$AST/etc/ast-bootstrap/keys" "$AST/var/cache/ast" "$AST"/{dev,proc,sys,run,sources}
cp "$KEY.pub" "$AST/etc/ast-bootstrap/keys/asteros.pub"
cat > "$AST/etc/ast-bootstrap/ast.toml" <<TOML
[core]
architecture = "x86_64"

[packages]
allow_untested = true

[build]
# a chroot cannot create the namespaces bubblewrap needs: the bootstrap builds unisolated, the
# installed system (the aster package) requires the sandbox
sandbox = "none"
uid = 0
gid = 0
jobs = $(nproc)
mirrors = ["file:///sources"]
TOML
cat > "$AST/etc/ast-bootstrap/repos.toml" <<TOML
[ast]
url = "file:///repo"
enabled = true
priority = 100
key = "asteros.pub"
channel = "stable"
TOML
cp /etc/resolv.conf "$AST/etc/resolv.conf" 2>/dev/null || true

if [ $# -gt 0 ]; then list="$*"; else list=$(grep -v '^#' "$HERE/bootstrap/base.list" | tr '\n' ' '); fi
cat > "$AST/stage4-chroot.sh" <<'INNER'
#!/bin/bash
set -e
# this build reads its own configuration (local repository, local sources, no sandbox)
ast() { command ast -C /etc/ast-bootstrap "$@"; }
ast -uy
for p in "$@"; do
    if ast -l | grep -q "^$p  "; then echo "== $p (installed)"; continue; fi
    echo "== $p"
    ast -iy --adopt "$p" || { echo "FAILED: $p"; exit 1; }
done
if [ "${POST:-1}" = 1 ]; then
# recipes that changed since the last run (the host-built ast of the first lines becomes the package)
# one package at a time: a failure keeps what is done, and a second run goes on from there
for p in "$@"; do
    ast -uy --adopt "$p" || { echo "FAILED: $p"; exit 1; }
done
# the cross toolchain of the first stages is not part of the system (the temporary tools were
# adopted by the packages; what no package owns and is named for the cross target goes)
rm -rf /usr/x86_64-aster-linux-gnu /usr/lib/gcc/x86_64-aster-linux-gnu /usr/libexec/gcc/x86_64-aster-linux-gnu /usr/include/c++/*/x86_64-aster-linux-gnu
rm -f /usr/bin/x86_64-aster-linux-gnu-*
# what only the build needed
for p in rust-bin; do ast -l | grep -q "^$p  " && ast -ry "$p"; done
fi
echo "== stage 4 done"
INNER
export STAGE4_POST=${STAGE4_POST:-1}   # 0: only the packages named, no upgrade or clean-up afterwards
exec unshare --mount --pid --fork --propagation private -- bash -ec '
    mount --rbind /dev "$0/dev"; mount --make-rslave "$0/dev"
    mount -t proc proc "$0/proc"
    mount --rbind /sys "$0/sys"; mount --make-rslave "$0/sys"
    mount -t tmpfs tmpfs "$0/run"
    mount --bind "$1" "$0/sources"
    shift 1
    exec chroot "$0" /usr/bin/env -i HOME=/root TERM="$TERM" PATH=/usr/bin:/usr/sbin LC_ALL=POSIX POST="$STAGE4_POST" /bin/bash /stage4-chroot.sh "$@"
' "$AST" "$SRC" $list
