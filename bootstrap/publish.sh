#!/bin/bash
# Publish the package repository into this repository, in repo/x86_64/stable: the signed index
# and the source archives of our own packages (work/dist). GitHub serves it at
# raw.githubusercontent.com/ast-os/ast-recipes/main/repo/x86_64/stable.
# Run it after the recipes are committed:  bootstrap/publish.sh [--push]
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
KEY=${ASTEROS_KEY:-$HOME/.config/asteros-keys/asteros}
out=$HERE/repo/x86_64/stable
rm -rf "$HERE/repo"; mkdir -p "$out"
"$HERE/ast/target/release/astpkg" publish "$HERE/recipes" --no-build --out "$out" --name ast --arch x86_64 --channel stable --key "$KEY.key" --files "$HERE/work/dist"
cd "$HERE"
git add -A repo
git commit -q -m "repo: the index and sources of $(git rev-parse --short HEAD)" || echo "nothing changed"
[ "$1" = --push ] && git push -q origin main
exit 0
