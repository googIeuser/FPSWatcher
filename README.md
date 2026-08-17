 # FPSWatcher Next v1.3.0

FPSWatcher Next is an Android game telemetry and session-analysis tool built with **Flutter**, **Kotlin**, and a focused **Rust** analytics/export core. The app intentionally exposes only two privileged telemetry backends: **Shizuku** and **Root**.

## Advanced telemetry

### Frame performance

- SurfaceFlinger FPS with `gfxinfo` fallback
- Rolling 5%, 1% and 0.1% low FPS
- Median, minimum and maximum instantaneous FPS
- Average, P95, P99, best and worst frame time
- Frame-time histogram and live FPS history
- Frame-pacing and frame-stability scores
- Micro-stutter, slow-frame, frozen-frame and 25/50/100 ms spike counters
- Estimated missed-VSync/dropped-frame count and refresh-rate mismatch detection

### CPU, scheduler and process

- System and foreground-game CPU load
- Per-core CPU load and frequency
- Current/min/max CPU policy clocks and governor
- Load-aware CPU throttling/headroom analysis
- PID, thread count, nice value, cpuset, uclamp, CPU affinity and scheduler policy
- Best-effort Android Game Mode and graphics-API information

### GPU

- Renderer/vendor detection
- Current/min/max GPU frequency
- GPU utilization and governor where exposed by the device
- Load-aware GPU throttling/headroom analysis
- Qualcomm KGSL, generic devfreq, Arm Mali, MediaTek GED and selected debugfs probes
- Raw GPU diagnostics for device bring-up

### Power, thermals and memory

- Battery-side discharge power, current and voltage
- Battery level, temperature and charge counter
- Battery drain in `%/h` and `mAh/h`
- Estimated remaining gaming time
- FPS-per-watt efficiency
- Android thermal status plus best-matching SoC/CPU/GPU thermal zones
- Thermal-stability score and throttling event detection
- Game PSS/RSS/native/graphics memory
- System RAM, swap, ZRAM and PSI memory pressure

### Network and display

- RX/TX throughput
- Non-blocking ping, jitter and packet-loss probe
- Wi-Fi RSSI, link speed, frequency and standard where Android exposes them
- Best-effort cellular network/signal summary
- Display refresh rate, refresh/FPS ratio and foreground game classification
- Best-effort foreground surface/window dimensions

### Monitor overhead

- Native collector latency
- FPSWatcher process CPU usage
- FPSWatcher PSS memory usage

## Sessions and reports

Sessions are recorded natively so collection can continue while the game is in the foreground. The app includes manual markers, automatic performance-event detection, first-half/second-half performance drift analysis, and exports to **CSV**, **JSON**, **HTML**, and dashboard **PNG**.

## Overlay

The overlay is native Android rather than Flutter. It has square corners and no backend label. Users can select 100/200/500 ms display refresh, vertical or horizontal layout, text size/color, padding, background opacity, adaptive warning colors, game-only visibility and individual metrics. Minimal, performance, thermal, battery, network and full telemetry presets are available.

## Diagnostics

The Diagnostics page acts as a device capability scanner and expert view. It reports backend health, per-metric availability/source, collector warnings, raw thermal zones, SurfaceFlinger excerpts, GPU probe output, per-core counters, scheduler/affinity information and monitor overhead.

## Shizuku and Root behavior

Shizuku runs with Android shell privileges, so protected kernel counters may remain unavailable on some ROMs. Root can access substantially more `/sys`, `/proc` and vendor/debug nodes. FPSWatcher never fabricates unavailable protected metrics. GPU load/frequency under Shizuku therefore depends on the device kernel and SELinux permissions.

## Sampling architecture

Fast counters and UI updates use short intervals while expensive `dumpsys`/process probes are independently cached. Network probing is asynchronous. Dashboard and overlay reuse short-lived snapshots to avoid duplicate shell work. Session recording uses buffered JSONL storage rather than flushing every sample.

## Repository workflow

The repository is GitHub Desktop friendly. Normal CI validates Flutter/Rust sources and publishes **only a debug APK artifact**. Signed universal/split APKs and the Play Store AAB are built exclusively by the **Stable Release** workflow using the persistent Android signing key supplied through GitHub Actions secrets; see [`docs/STABLE_RELEASE.md`](docs/STABLE_RELEASE.md).

## Portability notes

FPSWatcher is deliberately universal rather than vendor-specific. Exact counter availability varies across SoCs, kernels, Android versions and ROM security policy. Vendor-only game turbo modes, exact internal render resolution and some protected GPU counters cannot be guaranteed through a universal Shizuku path.
