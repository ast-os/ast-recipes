#!/bin/bash
# Publish the package repository: the signed index and the source archives of our own packages
# (work/dist), into the ast-repo repository. GitHub serves it at
# raw.githubusercontent.com/ast-os/ast-repo/main/x86_64/stable.
# Run it after the recipes are committed:  bootstrap/publish.sh [--push]
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
KEY=${ASTEROS_KEY:-$HOME/.config/asteros-keys/asteros}
out=$HERE/work/publish
remote=$(git -C "$HERE" remote get-url origin | sed 's/ast-recipes/ast-repo/')
rm -rf "$out"
git clone -q "$remote" "$out"
find "$out" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
mkdir -p "$out/x86_64/stable"
"$HERE/ast/target/release/astpkg" publish "$HERE/recipes" --no-build --out "$out/x86_64/stable" --name ast --arch x86_64 --channel stable --key "$KEY.key" --files "$HERE/work/dist"
cd "$out"
git add -A
git -c user.name="$(git -C "$HERE" log -1 --format=%an)" -c user.email="$(git -C "$HERE" log -1 --format=%ae)" commit -q -m "repo: the recipes and sources of $(git -C "$HERE" rev-parse --short HEAD)" || echo "nothing changed"
[ "$1" = --push ] && { git push -q origin HEAD:main && echo "pushed: https://raw.githubusercontent.com/ast-os/ast-repo/main/x86_64/stable/index.toml"; }
exit 0
