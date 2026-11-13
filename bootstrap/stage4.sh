#!/bin/bash
# Stage 4: build the base system with ast, from the recipes, inside the new system.
# Run it as: unshare -r --map-auto bootstrap/stage4.sh [PACKAGE...]   (default: everything in base.list)
set -e
. "$(dirname "$0")/env.sh"
[ "$(id -u)" = 0 ] || { echo "run it as: unshare -r --map-auto $0" >&2; exit 1; }
ASTBIN=$HERE/ast/target/release
KEY=$HERE/work/keys/asteros-dev

# ast itself, the recipes as a repository, its configuration, the sources as a mirror
install -m755 "$ASTBIN/ast" "$ASTBIN/astpkg" "$AST/usr/bin/"
rm -rf "$AST/repo"; mkdir -p "$AST/repo"
"$ASTBIN/astpkg" publish "$HERE/recipes" --no-build --out "$AST/repo" --name ast --arch x86_64 --channel stable --key "$KEY.key" >/dev/null
mkdir -p "$AST/etc/ast/keys" "$AST/var/cache/ast" "$AST"/{dev,proc,sys,run,sources}
cp "$KEY.pub" "$AST/etc/ast/keys/asteros-dev.pub"
cat > "$AST/etc/ast/ast.toml" <<TOML
[core]
architecture = "x86_64"

[packages]
allow_untested = true

[build]
sandbox = "none"
uid = 0
gid = 0
jobs = $(nproc)
mirrors = ["file:///sources"]
TOML
cat > "$AST/etc/ast/repos.toml" <<TOML
[ast]
url = "file:///repo"
enabled = true
priority = 100
key = "asteros-dev.pub"
channel = "stable"
TOML
cp /etc/resolv.conf "$AST/etc/resolv.conf" 2>/dev/null || true

if [ $# -gt 0 ]; then list="$*"; else list=$(grep -v '^#' "$HERE/bootstrap/base.list" | tr '\n' ' '); fi
cat > "$AST/stage4-chroot.sh" <<'INNER'
#!/bin/bash
set -e
ast -uy
for p in "$@"; do
    if ast -l | grep -q "^$p  "; then echo "== $p (installed)"; continue; fi
    echo "== $p"
    ast -iy --adopt "$p" || { echo "FAILED: $p"; exit 1; }
done
echo "== stage 4 done"
INNER
exec unshare --mount --pid --fork --propagation private -- bash -ec '
    mount --rbind /dev "$0/dev"; mount --make-rslave "$0/dev"
    mount -t proc proc "$0/proc"
    mount --rbind /sys "$0/sys"; mount --make-rslave "$0/sys"
    mount -t tmpfs tmpfs "$0/run"
    mount --bind "$1" "$0/sources"
    shift 1
    exec chroot "$0" /usr/bin/env -i HOME=/root TERM="$TERM" PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash /stage4-chroot.sh "$@"
' "$AST" "$SRC" $list
