# Legacy APK report

Inspected file: `FPSWatcher-v0.3.0-debug(1).apk`

## Package and implementation

- Package: `com.fpswatcher.app`
- Minimum API recorded in DEX metadata: 26
- Implementation: Java/Kotlin Android classes compiled to one `classes.dex`
- No Flutter engine assets or native Rust libraries were present.

## Detected components

- `MainActivity`
- `OverlayService`
- `MonitorEngine`
- `TelemetryRepository`
- `ForegroundAppDetector`
- `RootShell`
- `PermissionUtils`

## Detected data paths and commands

- CPU usage from `/proc/stat`
- CPU frequency from `/sys/devices/system/cpu/cpufreq`
- GPU probes for Qualcomm KGSL, devfreq GPU/Mali nodes, and Mali clock nodes
- SurfaceFlinger timestats for FPS
- RAM through `ActivityManager.MemoryInfo`
- Battery through Android battery APIs
- Foreground package through Usage Stats
- Thermal status through `PowerManager`
- Root provider detection for Magisk, KernelSU and SukiSU

## Main limitations

- GPU frequency/load depended almost entirely on root-readable sysfs nodes.
- No Shizuku backend.
- No Rust data parser.
- No session history.
- No PNG or CSV export.
- UI was generated with native Android views rather than Flutter.
