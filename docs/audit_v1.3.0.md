# v1.3.0 source audit

This audit documents checks performed on the source package before handoff. It is not a substitute for CI or physical-device validation.

## Structural checks

- XML resources parse successfully.
- GitHub Actions and project YAML files parse successfully.
- `rust/Cargo.toml` parses successfully.
- Repository shell scripts pass `bash -n`.
- Embedded foreground, network, privileged system, GPU and frame-stat shell programs pass `bash -n` after Kotlin interpolation is resolved for syntax checking.
- `TelemetrySample` constructor, native decoder and parser-merge constructor contain the same complete field set.
- Dart and Kotlin overlay preference keys are synchronized.
- No APK, AAB, `.idea`, `.gradle`, `build`, or `local.properties` output is included in the source tree.

## Defects fixed during the audit

- Removed a duplicated Dart `Wrap.spacing` named argument.
- Removed a duplicated Rust `filter_map` in the gfxinfo frame parser.
- Prevented live FPS graph history from retaining repeated raw SurfaceFlinger and GPU diagnostic strings.
- Avoided redundant Rust FFI parsing when Kotlin has already produced authoritative native metrics.
- Rate-limited expensive thermal-zone and process graphics-API probes independently from fast CPU/GPU/power counters.
- Made game-only overlay visibility tolerant of an unknown Android application category while still hiding applications explicitly categorized as non-games.

## Device-dependent limitations

Shizuku runs as Android's shell UID. Kernel/SELinux policy can prevent it from reading GPU devfreq, thermal, scheduler, battery or process nodes. Root can expose more counters, but file paths still vary by kernel and SoC. Missing protected counters remain unavailable rather than being synthesized.

SurfaceFlinger and `gfxinfo` output formats can differ across Android versions and vendor builds. FPSWatcher keeps both paths and exposes the active source in Diagnostics.

The foreground window dimensions are a best-effort window/surface indicator and must not be described as guaranteed internal render resolution. Cellular and vendor game-mode data are likewise best-effort.

## Final verification

The authoritative compile/test gate remains GitHub CI: Rust tests, Flutter analyzer/tests, Rust Android libraries and the Android debug build. Physical Root and Shizuku device testing is still required for vendor-specific telemetry coverage.
