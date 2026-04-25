#!/usr/bin/env bash
set -euo pipefail

# Usage: ./version-bump.sh <X.Y.Z>

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be X.Y.Z"
  exit 1
fi

echo "Bumping version to $VERSION"

########################################
# 1. build.zig.zon (ONLY root version)
########################################
if [[ -f build.zig.zon ]]; then
  awk -v ver="$VERSION" '
  BEGIN { in_root = 0; replaced = 0 }

  {
    if ($0 ~ /\.name[[:space:]]*=/) {
      in_root = 1
    }

    if (in_root && !replaced && $0 ~ /\.version[[:space:]]*=/) {
      sub(/"[0-9]+\.[0-9]+\.[0-9]+"/, "\"" ver "\"")
      replaced = 1
    }

    print
  }' build.zig.zon > build.tmp && mv build.tmp build.zig.zon

  echo "Updated build.zig.zon"
fi

########################################
# 2. README badge only
########################################
if [[ -f README.md ]]; then
  sed -E -i.bak \
    "s|(version-)[0-9]+\.[0-9]+\.[0-9]+(-blue)|\1${VERSION}\2|g" \
    README.md

  rm -f README.md.bak
  echo "Updated README.md"
fi

echo "Done."
