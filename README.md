# ast-recipes

The recipes of asterOS, and the scripts that build the base system from them. asterOS is
source-based: `ast -i NAME` builds a package from its recipe, binaries are released rarely.

```
recipes/NAME/NAME.recipe.toml   one recipe per package (see ast-pm: docs/format.md)
bootstrap/                      the base system from nothing, in four stages
files/aster/                    the source of the aster package: os-release, profile, fstab, the configuration and key of ast
```

## Recipes

A recipe names the source and its checksum and a build style; only what differs from the
style is written out:

```toml
[package]
name = "zlib"
version = "1.3.1"
description = "Compression library"
license = "Zlib"
arch = ["x86_64"]

[source]
url = "https://zlib.net/fossils/zlib-1.3.1.tar.gz"
sha256 = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"

[build]
style = "gnu"            # gnu, cmake, meson or cargo; own scripts replace the style's
fixup = '''
rm -f "$DESTDIR/usr/lib/libz.a"
'''
```

Publish the recipes as a repository: `astpkg publish recipes --no-build --out DIR --name ast --arch x86_64 --channel stable --key KEY`.

## Bootstrap

No root, no Yocto: a user namespace stands in for root. It needs the host compiler, `make`,
`curl`, and the sources of the base in `work/sources`.

```
bootstrap/stage1.sh                          # a cross toolchain in work/root/tools
bootstrap/stage2.sh                          # the temporary tools, cross-compiled into work/root
unshare -r --map-auto bootstrap/stage3.sh    # in the new system: perl, python, util-linux, ...
unshare -r --map-auto bootstrap/stage4.sh    # ast builds the base from the recipes (build order: base.list)
unshare -r --map-auto bootstrap/stage4.sh linux
unshare -r --map-auto bootstrap/mkstage.sh   # the base system as a tree and one tarball
bootstrap/hosttools.sh                       # xorriso, for the ISO, built on the host
unshare -r --map-auto bootstrap/mkiso.sh     # the live ISO: the system as a squashfs
```

Stages 1 to 3 follow Linux From Scratch 12.4 (kernel headers 6.16.1; glibc 2.42 does not build
with newer ones). Stage 4 uses `ast` itself: every package of the base is installed by it, over
the temporary tools (`--adopt`).

## Installing

By hand, from the live ISO, the way Gentoo is: see [INSTALL.md](INSTALL.md).
