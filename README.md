# FPSWatcher Next v1.2.4

FPSWatcher Next is an Android game telemetry monitor built with Flutter, Rust and a Kotlin platform layer. The app exposes only two telemetry backends: **Shizuku** and **Root**.

## Telemetry

- SurfaceFlinger FPS with `gfxinfo` fallback
- Rolling 30-second 1% low and 0.1% low FPS
- Average, P95 and P99 frame time
- Game PID, CPU usage, PSS and RSS memory
- System CPU usage, policy clocks, per-policy frequencies and governor
- GPU model, utilization, current clock and maximum clock when the kernel exposes readable counters
- Battery-side discharge watts, current, voltage, level and temperature
- SoC temperature, Android thermal status, system RAM, network and display data

Shizuku can read only what Android's shell user is permitted to read. Root checks protected Qualcomm KGSL, Mali/devfreq, PowerVR, MediaTek GED and debugfs paths. Protected GPU counters are shown as unavailable rather than fabricated.

## Refresh architecture

- Dashboard and native overlay share one short-lived telemetry snapshot to avoid duplicate shell work.
- Fast CPU/GPU/power counters are polled at 100–250 ms depending on the selected UI interval.
- Slow process PSS/CPU and vendor dumpsys probes are cached for 1.5 seconds.
- FPS is sampled in one-second windows and accumulated into a 30-second rolling statistics window.
- Session recording stores two samples per second and buffers disk writes.
- Dashboard polling pauses on Settings; the Session page performs lightweight recording syncs.

## Overlay

The native overlay has square corners, background-only opacity, selectable text size/color/padding/refresh rate, per-metric visibility, an in-app preview and a remembered on-screen position. It does not display the backend name.

## GitHub Desktop

Extract the ZIP, use **File → Add local repository**, then commit and push. The included GitHub Actions workflow analyzes/tests Flutter and Rust, builds the Android host, and uploads debug/release APK artifacts.

## Stable GitHub releases

`.github/workflows/ci.yml` verifies pushes and pull requests. `.github/workflows/release.yml` publishes persistently signed APK/AAB files when run manually or when a `vX.Y.Z` tag is pushed. See [`docs/STABLE_RELEASE.md`](docs/STABLE_RELEASE.md) for signing-secret setup.
