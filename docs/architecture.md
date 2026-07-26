# Architecture

## Layers

### Flutter UI (`lib/`)

- Material 3 dashboard, session recorder, access settings and export controls.
- 200 ms live refresh by default, selectable as 200/500/1000 ms.
- Android MethodChannel bridge for telemetry, permissions, overlay control, native recording and Storage Access Framework exports.
- Rust FFI loader with Dart fallbacks when the native library is unavailable.

### Rust core (`rust/`)

- SurfaceFlinger timestats and gfxinfo frame parser.
- 1% low, 0.1% low, average/P95/P99 frame-time calculations.
- GPU frequency/load parser for common vendor output formats.
- Detailed CSV generator with proper cell escaping.
- Built as `libfpswatcher_core.so` for arm64-v8a, armeabi-v7a and x86_64.

### Kotlin Android layer (`platform/android_overlay/`)

- Standard Android telemetry collector with per-metric failure isolation.
- EGL GPU renderer probe.
- Shizuku UserService and AIDL command bridge.
- SukiSU/KernelSU/Magisk-compatible root shell fallback.
- Foreground monitor service, 200 ms draggable overlay and two-samples-per-second native session store.
- Lightweight counters are collected every UI tick; privileged FPS/process/GPU probes are cached for 200 ms, while frame statistics use a 1 second window to limit overhead.

## Recording flow

1. Flutter requests `startRecording` with the selected access mode.
2. The Kotlin foreground service starts and refreshes the overlay every 200 ms.
3. A detailed recording sample is stored every 500 ms.
4. Each sample is mirrored to a private JSON-lines recovery file while the bounded in-memory window is updated.
5. The Flutter activity stops its own timer while backgrounded, avoiding duplicate telemetry queries during gameplay.
6. CSV export requests the native session and passes it to the Rust CSV generator.

## Access behavior

| Metric | Standard | Shizuku | Root |
|---|---:|---:|---:|
| GPU renderer/model through EGL | Yes | Yes | Yes |
| GPU frequency/load | Only public readable nodes | Shell-readable KGSL/devfreq/vendor nodes | Widest sysfs/debugfs coverage |
| Game FPS, 1% low, 0.1% low | No cross-app frame source | SurfaceFlinger with gfxinfo fallback | SurfaceFlinger with gfxinfo fallback |
| Average/P95/P99 frame time | No cross-app frame source | Yes when a frame source is available | Yes when a frame source is available |
| Foreground package | Usage Access | Usage Access plus dumpsys fallback | Usage Access plus dumpsys fallback |
| Game process CPU/PSS/RSS | Usually restricted | `/proc` and dumpsys | `/proc` and dumpsys |
| System CPU/RAM/battery/network/storage | Yes where Android exposes it | Yes | Yes |
| Instant battery-side watts | Android current × voltage | API plus readable power-supply sysfs | API plus protected power-supply sysfs |
| SoC thermal sensors | Android thermal status | Readable thermal sysfs | Widest thermal sysfs coverage |

GPU utilization and clock paths are vendor kernel interfaces rather than public standardized Android APIs. Missing protected values remain unavailable instead of being estimated or fabricated.
