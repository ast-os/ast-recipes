# ast-recipes

Recipes of asterOS and the scripts that build the base system from them.

```
recipes/NAME/NAME.recipe.toml   one recipe per package (format: ast-pm, docs/format.md)
bootstrap/                      the base system from nothing, in four stages
files/aster/                    source of the aster package: os-release, profile, fstab, ast config
```

## Bootstrap

No root: a user namespace stands in for it. Needs the host compiler, `make`, `curl`.

```
bootstrap/stage1.sh                          # cross toolchain
bootstrap/stage2.sh                          # temporary tools
unshare -r --map-auto bootstrap/stage3.sh    # tools inside the new system
unshare -r --map-auto bootstrap/stage4.sh    # ast builds the base (order: base.list)
unshare -r --map-auto bootstrap/mkstage.sh   # stage tarball
bootstrap/hosttools.sh                       # xorriso, built on the host
unshare -r --map-auto bootstrap/mkiso.sh     # live ISO
```

Install: [INSTALL.md](INSTALL.md).
