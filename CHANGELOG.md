# Changelog

## 1.0.3

- Assigned an explicit AIDL transaction ID (`0`) to `execute` so every method in `IPrivilegedService` uses manual IDs.
- Preserved Shizuku's required `destroy` transaction ID (`16777114` in AIDL).
- Fixes the Android `compileDebugAidl` failure with Build Tools 36.

## 1.0.2

- Migrated the Android application module to AGP 9 built-in Kotlin.
- Removed the legacy `kotlin-android` plugin from the app module.
- Replaced the deprecated `android.kotlinOptions` block with the typed `kotlin.compilerOptions` DSL targeting JVM 17.
- Keeps the project on the current AGP DSL instead of relying on temporary legacy opt-out flags.

## 1.0.1

- Removed two redundant `dart:typed_data` imports that caused `flutter analyze` to exit with code 1 in GitHub Actions.
- No runtime or telemetry behavior changed.

## 1.0.0

- Rebuilt the application with a Flutter UI, Rust parsing/export core, and Kotlin Android platform layer.
- Added Standard, Shizuku, Root, and root-safe Auto access modes.
- Added rootless GPU renderer detection through EGL.
- Added privileged GPU frequency/load, game-process CPU/RAM, CPU frequency, and SoC thermal probing through Shizuku or root.
- Added interval-based SurfaceFlinger FPS, P90, and P99 parsing.
- Added a movable foreground overlay.
- Added native background session recording that continues while a game is foregrounded.
- Added PNG and full-session CSV export through Android's system file picker.
- Added a completely new dashboard and application icon.
