# FPSWatcher Next v1.1.0

FPSWatcher Next is a rootless-first Android game telemetry monitor built with Flutter, Rust and a Kotlin platform layer.

## Telemetry coverage

### Standard mode — no root, no Shizuku

- System CPU usage and readable CPU clocks
- System RAM and storage
- Battery level, temperature, current, voltage and battery-side power estimate
- Android thermal status and display refresh rate
- Network receive/transmit speed
- Foreground package through Usage Access
- GPU renderer/model through EGL
- GPU load/clock only when the vendor exposes readable public sysfs nodes

### Shizuku mode

Adds every counter available to Android's shell user:

- Real game FPS from SurfaceFlinger timestats, with gfxinfo fallback
- 1% low and 0.1% low FPS
- Average, P95 and P99 frame time
- Foreground game PID, CPU usage and PSS/RSS memory
- CPU policy clocks and governor
- GPU load/current clock/max clock when shell-readable
- Additional battery and thermal sysfs values

### Root mode

Uses standard `su -c`, compatible with SukiSU, KernelSU and Magisk. It performs the same probes with root access and also checks protected Qualcomm KGSL, Mali/devfreq, PowerVR, MediaTek GED and debugfs nodes.

GPU utilization and clock counters are vendor kernel interfaces, not public Android APIs. FPSWatcher never fabricates a value. When Standard and Shizuku cannot read a GPU counter, the model remains visible and the protected value is marked unavailable; Root may unlock it.

## Refresh model

- Live Flutter dashboard: 250 ms by default, selectable as 250/500/1000 ms
- Lightweight Android counters: every dashboard tick
- FPS, game process and privileged GPU probes: every 250 ms in the fast live path
- Floating overlay: 250 ms
- Session recording: two samples per second

## Main features

- Real FPS, 1% low, 0.1% low and frame-time percentiles
- Game CPU usage and game PSS/RSS memory
- System CPU utilization, per-policy clock range and governor
- GPU model, load, current clock and maximum clock when exposed
- Instant battery-side watts, current, voltage and battery temperature
- SoC thermal data, system RAM, network and display data
- Draggable detailed in-game overlay
- PNG dashboard export
- Detailed CSV session export powered by the Rust core
- Root → Shizuku → Standard provider selection with operational checks

## GitHub Desktop

Extract the ZIP, add the folder using **File → Add local repository**, commit and push it. The included GitHub Actions workflow builds debug and release APK artifacts after a push to `main` or `master`.

## Required Android access

- Usage Access identifies the foreground game.
- Display over other apps enables the floating overlay.
- Notification permission keeps the monitor service visible on Android 13+.
- Shizuku and root are optional and only used when available.
