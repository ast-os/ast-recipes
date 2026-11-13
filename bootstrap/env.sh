# Shared by the bootstrap stages. Source it; nothing here runs anything.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export AST=$HERE/work/root              # the system under construction
export SRC=$HERE/work/sources
export BUILD=$HERE/work/build
export AST_TGT=x86_64-aster-linux-gnu
export PATH=$AST/tools/bin:/usr/bin:/bin
export LC_ALL=POSIX CONFIG_SITE=$AST/usr/share/config.site
export MAKEFLAGS=-j$(nproc)
umask 022
mkdir -p "$BUILD" "$AST"

# unpack NAME-VERSION archive into a fresh build directory and enter it
unpack() {
    local f; f=$(ls "$SRC"/$1.tar.* "$SRC"/$1.tgz 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "no source for $1" >&2; return 1; }
    rm -rf "$BUILD/$1"; mkdir -p "$BUILD/$1"
    tar -xf "$f" -C "$BUILD/$1" --strip-components=1
    cd "$BUILD/$1"
}
log() { printf '== %s\n' "$*"; }

# the host compiler may default to a newer C++ than gcc's own host programs accept; only the gcc
# builds get it (it would break the configure of everything that is cross-compiled)
HOST_CXX="g++ -std=gnu++17"

# step NAME CMD...: run CMD once; a finished step is skipped when the stage is run again
step() {
    local name=$1; shift
    if [ -f "$BUILD/.done.$name" ]; then log "$name (already done)"; return 0; fi
    log "$name"
    ( set -e; "$@" )
    touch "$BUILD/.done.$name"
}
