$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not installed or not in PATH."
}

$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("fpswatcher-" + [guid]::NewGuid())
try {
    flutter create --platforms=android --android-language=kotlin --org com.fpswatcher --project-name fps_watcher (Join-Path $Temp "generated")
    if (Test-Path android) { Remove-Item android -Recurse -Force }
    Copy-Item (Join-Path $Temp "generated/android") android -Recurse
    if (Test-Path "android/app/src/main") { Remove-Item "android/app/src/main" -Recurse -Force }
    Copy-Item "platform/android_overlay/app/build.gradle.kts" "android/app/build.gradle.kts" -Force
    New-Item -ItemType Directory -Force -Path "android/app/src" | Out-Null
    Copy-Item "platform/android_overlay/app/src/main" "android/app/src/main" -Recurse -Force
    New-Item -ItemType Directory -Force -Path "android/app/src/main/jniLibs" | Out-Null
    Write-Host "Android host project generated and FPSWatcher platform layer applied."
}
finally {
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
}
