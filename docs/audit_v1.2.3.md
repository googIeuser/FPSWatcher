# v1.2.3 stability and design audit

The audit focused on repeated launches, MethodChannel values, backend lifecycle, overlay/service concurrency, frame statistics, battery power and long session exports.

## Corrected

- Discharging was previously matched as charging because the string `discharging` contains `charging`. Battery status now uses exact values.
- Dashboard and overlay collectors now share snapshots for near-simultaneous requests.
- Fast and slow telemetry have separate polling intervals.
- SurfaceFlinger/gfxinfo frame samples use a 30-second rolling window and minimum frame counts for low-FPS statistics.
- Gfxinfo is reset after each fallback sample to avoid duplicate frames.
- A failed `su` candidate no longer prevents later SukiSU/KernelSU/Magisk candidates from being tested.
- Backend checks for overlay/recording run off the UI thread.
- Session disk writes are buffered; corrupt JSONL rows are skipped; large MethodChannel transfers are paginated.
- Persisted backend selection and overlay values are normalized.
- Overlay position is clamped to the screen and update callbacks stop after service destruction.

## Platform limitations

- Shizuku GPU utilization/frequency is available only when the device kernel exposes counters readable by Android's shell UID.
- 0.1% low remains blank until at least 1,000 valid frames have entered the rolling window.
- Discharge wattage is hidden while charging because battery current then represents net battery flow rather than total device consumption.
