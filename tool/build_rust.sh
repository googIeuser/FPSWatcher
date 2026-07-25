#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v rustup >/dev/null 2>&1 || { echo "Rust is not installed or not in PATH." >&2; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Cargo is not installed or not in PATH." >&2; exit 1; }
if ! command -v cargo-ndk >/dev/null 2>&1; then
  cargo install cargo-ndk --locked
fi

rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
mkdir -p android/app/src/main/jniLibs
cd rust
cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -t x86_64 \
  -o ../android/app/src/main/jniLibs \
  build --release

echo "Rust Android libraries built successfully."
