#!/bin/bash
# Sign the index of the recipes tree: recipes/index.toml and recipes/index.toml.sig. `ast -u`
# reads them from raw.githubusercontent.com/ast-os/ast-recipes/main/recipes.
# Run after the recipes are committed, then commit the index:  bootstrap/index.sh
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
KEY=${ASTEROS_KEY:-$HOME/.config/asteros-keys/asteros}
"$HERE/tools/target/release/astpkg" index "$HERE/recipes" --name ast --arch x86_64 --channel stable --key "$KEY.key"
