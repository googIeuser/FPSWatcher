# Changelog

## 1.0.5

- Fixed Android 17 display collection by resolving the default display through `DisplayManager` instead of reading `Context.display` from an application context.
- Isolated every metric so a single vendor/API failure no longer stops the full telemetry snapshot.
- Added operational Shizuku UserService checks and automatic Shizuku → root → standard fallback.
- Added SukiSU/KernelSU-compatible `su -c` probing and truthful root status reporting.
- Added Usage Access, Shizuku and root foreground-app fallbacks.
- Expanded universal Adreno, Mali, PowerVR and MediaTek GPU node discovery.
- Fixed dashboard card overflows and removed raw platform exceptions from the main UI.
- Added charging/current/voltage fields to live telemetry and CSV exports.
- Hides the floating overlay over FPSWatcher and Android permission/settings screens.

## 1.0.4

- Enabled Android `BuildConfig` generation in the app module so `ShizukuClient` can read `BuildConfig.DEBUG` under AGP 9.
- Replaced the invalid literal-color `android:drawable` value in `launch_background.xml` with a nested rectangle shape and solid color.
- Updated GitHub-maintained workflow actions to their Node.js 24 major versions (`checkout`, `setup-java`, and `upload-artifact`).
- Fixes the `compileDebugKotlin` and `processDebugResources` failures seen after the AIDL stage.

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
