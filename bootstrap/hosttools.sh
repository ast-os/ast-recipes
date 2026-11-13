#!/bin/bash
# The tools that make the live medium and are not part of the base: xorriso (libburn, libisofs,
# libisoburn), built from the recipes' sources with the host compiler into work/host.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
HOST=$HERE/work/host
SRC=$HERE/work/sources
[ -x "$HOST/bin/xorriso" ] && { echo "$HOST/bin/xorriso (already built)"; exit 0; }
export PKG_CONFIG_PATH=$HOST/lib/pkgconfig LD_LIBRARY_PATH=$HOST/lib CPPFLAGS=-I$HOST/include LDFLAGS="-L$HOST/lib -Wl,-rpath,$HOST/lib"
# libtool runs ldconfig after an install; there is nothing to refresh outside the prefix
shim=$(mktemp -d); printf '#!/bin/sh\nexit 0\n' > "$shim/ldconfig"; chmod +x "$shim/ldconfig"; export PATH=$shim:$PATH
for p in libburn libisofs libisoburn; do
    v=$(sed -n 's/^version = "\(.*\)"/\1/p' "$HERE/recipes/$p/$p.recipe.toml" | head -1)
    dir=$(mktemp -d)
    tar -xf "$SRC/$p-$v.tar.gz" -C "$dir" --strip-components=1
    (cd "$dir" && ./configure --prefix="$HOST" --disable-static >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null)
    rm -rf "$dir"; echo "$p $v"
done
rm -rf "$shim"
