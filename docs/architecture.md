# Architecture

## Layers

### Flutter UI (`lib/`)

- Material 3 dashboard, session recorder, access settings, and export controls.
- One-second live refresh only while the Flutter activity is resumed.
- Android MethodChannel bridge for telemetry, permissions, overlay control, native recording, and Storage Access Framework exports.
- Rust FFI loader with Dart fallbacks when the native library is unavailable.

### Rust core (`rust/`)

- SurfaceFlinger timestats parser.
- GPU frequency/load parser for common vendor output formats.
- CSV generator with proper cell escaping.
- Built as `libfpswatcher_core.so` for arm64-v8a, armeabi-v7a, and x86_64.

### Kotlin Android layer (`platform/android_overlay/`)

- Standard Android telemetry collector.
- EGL GPU renderer probe.
- Shizuku UserService and AIDL command bridge.
- Explicit root shell fallback.
- Foreground monitor service, draggable overlay, and native session store.
- Android Storage Access Framework writer for PNG and CSV.

## Recording flow

1. Flutter requests `startRecording` with the selected access mode.
2. The Kotlin foreground service starts and collects one sample per second.
3. Each sample is mirrored to a private JSON-lines recovery file while the bounded in-memory window is updated.
4. The Flutter activity stops its own timer when it moves to the background, avoiding duplicate heavy telemetry queries while a game is foregrounded.
5. Native samples remain available when the user returns to the app.
6. CSV export requests the complete native session and passes it to the Rust CSV generator.

## Access behavior

| Metric | Standard | Shizuku | Root |
|---|---:|---:|---:|
| GPU renderer/model through EGL | Yes | Yes | Yes |
| GPU frequency/load | Best effort readable nodes | Enhanced best effort | Widest best effort |
| Game FPS/P90/P99 | No privileged game-layer source | SurfaceFlinger best effort | SurfaceFlinger best effort |
| Foreground package | Usage Access | Usage Access | Usage Access |
| Game process CPU/RAM | Usually restricted | `/proc` plus dumpsys fallback | `/proc` plus dumpsys fallback |
| System CPU/RAM/battery/network/storage | Yes where Android exposes it | Yes | Yes |
| SoC thermal sensors | Android thermal status | Thermal sysfs best effort | Thermal sysfs best effort |

No Android API guarantees third-party access to every GPU or SurfaceFlinger counter. The app reports unavailable values as missing rather than inventing estimates.
