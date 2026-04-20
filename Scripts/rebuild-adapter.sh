#!/usr/bin/env bash
# Rebuild the MediaRemoteAdapter.framework from the vendored source.
# Needed once after cloning, or after updating Vendor/mediaremote-adapter-src.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Vendor/mediaremote-adapter-src"
BUILD="${SRC}/build"
rm -rf "${BUILD}"
cmake -S "${SRC}" -B "${BUILD}" -G Ninja
cmake --build "${BUILD}"

rm -rf Resources/MediaRemoteAdapter.framework
cp -R "${BUILD}/MediaRemoteAdapter.framework" Resources/
cp "${SRC}/bin/mediaremote-adapter.pl" Resources/

echo "==> Framework refreshed at Resources/MediaRemoteAdapter.framework"
