#!/bin/bash
# Publish the repository the installed systems read: the recipes, their signed index and the
# source archives of our own packages (work/dist), as the `repo` branch of this repository; GitHub
# serves it at raw.githubusercontent.com/ast-os/ast-recipes/repo/x86_64/stable. The branch holds
# only generated files; every publish is one more commit.
# Run it after the recipes are committed:  bootstrap/publish.sh [--push]
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
KEY=${ASTEROS_KEY:-$HOME/.config/asteros-keys/asteros}
out=$HERE/work/publish
remote=$(git -C "$HERE" remote get-url origin)
# continue the branch: every publish is a commit on top of the last one
rm -rf "$out"
git clone -q --depth 1 -b repo "$remote" "$out" 2>/dev/null || { mkdir -p "$out"; git -C "$out" init -q -b repo; }
find "$out" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
mkdir -p "$out/x86_64/stable"
"$HERE/ast/target/release/astpkg" publish "$HERE/recipes" --no-build --out "$out/x86_64/stable" --name ast --arch x86_64 --channel stable --key "$KEY.key" --files "$HERE/work/dist"
cd "$out"
git add -A
git -c user.name="$(git -C "$HERE" log -1 --format=%an)" -c user.email="$(git -C "$HERE" log -1 --format=%ae)" commit -q -m "repo: the recipes and sources of $(git -C "$HERE" rev-parse --short HEAD)" || echo "nothing changed"
if [ "$1" = "--push" ]; then
    git push -q origin repo
    echo "pushed: https://raw.githubusercontent.com/ast-os/ast-recipes/repo/x86_64/stable/index.toml"
else
    echo "$out  (not pushed: --push does that)"
fi
