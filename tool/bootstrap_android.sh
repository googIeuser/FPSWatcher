#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter is not installed or not in PATH." >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

flutter create \
  --platforms=android \
  --android-language=kotlin \
  --org com.fpswatcher \
  --project-name fps_watcher \
  "$TMP_DIR/generated"

rm -rf android
cp -R "$TMP_DIR/generated/android" ./android
rm -rf android/app/src/main
cp platform/android_overlay/app/build.gradle.kts android/app/build.gradle.kts
mkdir -p android/app/src
cp -R platform/android_overlay/app/src/main android/app/src/main
mkdir -p android/app/src/main/jniLibs

echo "Android host project generated and FPSWatcher platform layer applied."
