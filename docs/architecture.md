# Architecture

FPSWatcher uses three deliberately separated layers.

## Flutter

Flutter owns dashboard rendering, session/report UX, diagnostics, settings, charts and state management. It does not directly own the game overlay or privileged shell lifecycle.

## Kotlin / Android

The Android layer owns Shizuku and root execution, foreground-game detection, foreground service lifecycle, native overlay windows, Android framework metrics, kernel/sysfs probes, session persistence and MethodChannel sanitization. One failed sensor is isolated from the rest of a snapshot.

Fast CPU/GPU/power counters are separated from expensive process/dumpsys probes. Network probing runs asynchronously. Short-lived snapshot sharing prevents the dashboard and overlay from issuing duplicate privileged commands.

## Rust

Rust is intentionally limited to computation-heavy, portable parsing and export work: SurfaceFlinger/gfxinfo frame parsing, rolling tail statistics, frame-pacing calculations, GPU text parsing and CSV generation. Android system access remains in Kotlin to avoid unnecessary JNI/FFI complexity.

## Backends

Only Shizuku and Root are exposed. Shizuku capability is limited to what Android's shell UID and SELinux policy can read. Root uses standard `su -c` behavior and is compatible with managers such as KernelSU/SukiSU and Magisk when permission is granted.

## Data integrity

Every MethodChannel value is recursively converted to StandardMessageCodec-safe Dart/Kotlin primitives. Persisted sessions use buffered JSONL, tolerate corrupt rows and omit very large transient histogram/raw fields where appropriate. Missing metrics stay missing rather than being replaced with fabricated zeroes.
