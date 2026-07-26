# Changelog

## 1.2.4

- Fixed AAB signature verification: self-signed Android release certificates are accepted while the JAR signature and embedded certificate are still validated.
- Fixed stable-release secret mapping so the workflow reads the documented `FPSWATCHER_*` repository secrets.
- Added separate CI and stable release GitHub Actions workflows.
- Stable releases now use a persistent Android signing key stored through GitHub Actions secrets instead of the debug key.
- Added automatic version/changelog validation, signature verification, universal and split APK builds, Play Store AAB output, SHA-256 checksums and build provenance attestations.
- Added a manual Actions release flow that creates the semantic version tag and publishes the release without requiring local tag commands.
- Pinned Flutter and cargo-ndk versions used by CI for repeatable builds.

## 1.2.3

- Fixed privileged battery status parsing: `Discharging` is no longer mistaken for `Charging`, restoring watt telemetry on affected devices.
- Prevents dashboard and overlay from running duplicate expensive collectors by sharing a short-lived process telemetry cache.
- Split fast counters from slow `dumpsys` probes; CPU/GPU/power remain responsive without running meminfo/cpuinfo on every 100 ms tick.
- Added a rolling 30-second frame histogram. 1% low requires at least 100 frames and 0.1% low requires at least 1,000 frames.
- Resets `gfxinfo` after fallback frame collection to avoid counting the same frames repeatedly.
- Buffered session writes and skips corrupt JSONL rows instead of breaking session restoration.
- Fixed root shell fallback so a broken earlier `su` candidate does not prevent SukiSU/KernelSU/Magisk from being tried.
- Validates Shizuku/Root before starting overlay or recording, without blocking the Flutter UI thread.
- Added overlay lifecycle guards, on-screen drag clamping, background-only opacity and an in-app overlay preview.
- Persists the selected Shizuku/Root backend across app restarts.
- Pages large recorded sessions through MethodChannel to avoid one oversized codec envelope.
- Hardened all persisted telemetry type parsing and kept native metrics authoritative over Rust fallback parsing.
- Stops live dashboard polling while viewing Settings; Session uses lightweight two-second recording syncs.
- Charging state is shown explicitly and discharge wattage is intentionally hidden while charging.

## 1.2.2

- Fixed a repeat-launch crash caused by persisted CPU core-frequency arrays being loaded as `org.json.JSONArray`.
- Recursively converts `JSONArray`, `JSONObject`, nested maps and arrays into Flutter `StandardMessageCodec` compatible values.
- Sanitizes all telemetry, status, overlay-preference and recorded-session MethodChannel responses at the Android boundary.
- Existing persisted sessions are migrated in memory automatically; clearing app data is not required.

## 1.2.1

- Removed an unused `overlay_preferences.dart` import from `settings_page.dart`.
- Fixes the GitHub Actions failure at the `flutter analyze` step.
- No runtime telemetry or overlay behavior changed.

## 1.1.1

- Fixed Auto mode silently remaining on Standard when SukiSU/KernelSU permission had not been actively requested.
- Added an explicit Root access tile and native root permission request.
- Added robust `su` path probing for SukiSU, KernelSU and Magisk.
- Reduced live CPU/GPU/power/process refresh to 200 ms while keeping FPS statistics on a stable 1 second capture window.
- Combined privileged system and GPU probes to reduce root/Shizuku process overhead.
- Added backend failure diagnostics instead of silently showing empty values.
- Filtered invalid near-zero battery power readings.

## 1.1.0

- Added true 1% low and 0.1% low calculations from frame-time tails.
- Added SurfaceFlinger FPS with gfxinfo fallback, average/P95/P99 frame time and FPS source labels.
- Added detailed game process CPU, PSS and RSS memory telemetry.
- Added CPU policy frequency range, per-policy clock list and governor reporting.
- Expanded Qualcomm KGSL, Mali/devfreq, PowerVR, MediaTek GED and debugfs GPU probes.
- Added GPU maximum frequency and source reporting; unavailable protected counters are never fabricated.
- Added battery sysfs power/current/voltage/temperature fallback and power-source reporting.
- Changed the dashboard and overlay refresh interval to 250 ms; privileged FPS, process and GPU probes run every 250 ms.
- Expanded the overlay and CSV recorder with all detailed counters.
- Removed local IDE/build helper material from the GitHub Desktop source package.

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
