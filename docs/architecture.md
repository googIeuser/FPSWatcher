# Architecture

FPSWatcher Next has three layers:

- **Flutter**: dashboard, session history, settings, PNG/CSV export and overlay preview.
- **Kotlin**: Android permissions, foreground detection, Shizuku/Root execution, telemetry scheduling, persistence and the native overlay.
- **Rust**: fallback frame/GPU parsing and CSV generation.

## Backend policy

Only Shizuku and Root are user-selectable. Starting the overlay or recorder fails with a clear error when the selected backend is not operational. No hidden Standard fallback is used.

## Collection policy

A process-local `TelemetrySnapshotCache` lets the Flutter activity and overlay service reuse the same fresh snapshot. The overlay service is the primary collector while it is active; the dashboard reuses its data. Fast sysfs/API counters and slow shell/dumpsys probes use separate polling intervals.

Frame histograms are accumulated for 30 seconds. 1% low is withheld until 100 frames are available, and 0.1% low until 1,000 frames are available. Native Kotlin values are authoritative; Rust only fills a missing parse result.

## Persistence

Recorded JSONL samples are sanitized into Flutter codec-compatible values, buffered before disk flush, capped in memory, compacted when oversized and restored row-by-row so one corrupt line does not discard the rest of a session.

## Overlay

Overlay preferences live in Android SharedPreferences. The square native TextView supports background-only opacity, per-metric visibility, refresh interval, text styling, drag-position persistence and screen-bound clamping. The Flutter settings page renders a matching preview.
