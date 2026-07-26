# Architecture

FPSWatcher Next uses three layers:

- Flutter for the dashboard, sessions, settings and overlay customization.
- Kotlin for Android permissions, Shizuku/Root command execution, foreground monitoring, telemetry collection and the native overlay service.
- Rust for frame-statistics parsing, GPU counter normalization and CSV generation.

## Backend policy

Only two backends are exposed:

1. Shizuku UserService for non-root devices.
2. Root through `su -c` for rooted devices.

The selected backend is used exactly; the collector does not silently report a third Standard mode. Public Android counters may still be included alongside the selected privileged backend.

## Overlay

Overlay settings are persisted with Android SharedPreferences and shared between Flutter and the foreground service. The overlay is a sharp-cornered native TextView, supports per-metric visibility, remembers its drag position and never displays the active backend name.
