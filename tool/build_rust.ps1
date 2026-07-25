$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root

if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) { throw "Rustup is not installed or not in PATH." }
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not installed or not in PATH." }
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
    cargo install cargo-ndk --locked
}

rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
New-Item -ItemType Directory -Force -Path "android/app/src/main/jniLibs" | Out-Null
Set-Location "rust"
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o ../android/app/src/main/jniLibs build --release
Write-Host "Rust Android libraries built successfully."
