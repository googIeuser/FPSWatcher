# Advanced feature matrix

## Implemented in v1.3.0

- FPS, 5% low, 1% low and 0.1% low
- Median/min/max FPS and average/P95/P99/best/worst frame time
- Frame-time histogram, frame-pacing score, frame-stability score and combined performance-stability score
- Micro-stutter, slow-frame, frozen-frame, 25/50/100 ms spike and estimated missed-VSync counters
- System/game CPU load, CPU policy clocks, governor, policy/cluster summary and per-core load/frequency where exposed
- PID, thread count, nice, cpuset, uclamp, affinity and scheduler policy
- GPU renderer/vendor, load, current/min/max clock and governor where the selected backend can read them
- Battery-side power/current/voltage, level, temperature, charge counter, drain rate, remaining gaming-time estimate and FPS/W
- SoC/CPU/GPU thermal-zone matching, Android thermal state and throttling heuristics
- PSS/RSS/native/graphics process memory, RAM, swap, ZRAM and PSI memory pressure
- RX/TX, ping, jitter, packet loss, Wi-Fi telemetry and best-effort cellular summary
- Refresh rate, FPS/refresh mismatch, foreground game category and best-effort game window dimensions
- Native session recording, manual markers, automatic event timeline and first-half/second-half drift comparison
- CSV, JSON and HTML session export plus dashboard PNG export
- Square native overlay, presets, horizontal/vertical layouts, adaptive warning colors, position persistence and per-metric visibility
- Capability matrix, backend diagnostics, source labels, raw SurfaceFlinger/GPU/thermal excerpts, actual sample interval and FPSWatcher CPU/RAM/collector-latency overhead

## Best-effort / device dependent

- Shizuku GPU load/frequency and thermal nodes
- Vendor GPU devfreq/debugfs paths
- Graphics API detection from process mappings
- Android Game Mode output
- Cellular signal details
- Foreground game categorization
- Foreground window/surface dimensions
- Scheduler/uclamp/cpuset details on hardened ROMs

These remain unavailable when Android's shell UID, SELinux or the vendor kernel denies access. Root usually exposes more data, but even root paths differ across kernels.

## Not guaranteed by a universal Android implementation

- Proprietary manufacturer Game Turbo/Game Booster state for every vendor
- Exact internal dynamic render resolution used inside every game engine
- Hardware power rails for isolated CPU-only or GPU-only wattage on every SoC
- True driver-level dropped-frame counters when the vendor does not expose them
- Protected GPU counters through Shizuku when the kernel denies shell access

## Future product-level features

The telemetry foundation is ready for persistent multi-session archives, imported cross-device comparisons, per-game profile databases, automatic game-triggered recording and screenshot-linked bookmarks. Those features require additional persistence/profile/media UX rather than more low-level counters and are intentionally separated from this telemetry-focused release.
