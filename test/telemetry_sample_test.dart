import 'package:flutter_test/flutter_test.dart';
import 'package:fps_watcher/src/models/overlay_preferences.dart';
import 'package:fps_watcher/src/models/telemetry_sample.dart';

void main() {
  test('exposes only Shizuku and Root access modes', () {
    expect(AccessMode.values, [AccessMode.shizuku, AccessMode.root]);
  });

  test('merges parsed FPS and GPU values', () {
    final sample = TelemetrySample.fromNative({
      'cpuUsage': 40,
      'gpuModel': 'Adreno',
      'surfaceFlingerRaw': 'averageFPS = 60',
    });
    final merged = sample.mergeParsed(
      fpsData: {
        'averageFps': 59.8,
        'onePercentLowFps': 42.0,
        'pointOnePercentLowFps': 31.0,
      },
      gpuData: {
        'loadPercent': 72.0,
        'frequencyMhz': 900.0,
        'maxFrequencyMhz': 1100.0,
      },
    );
    expect(merged.fps, 59.8);
    expect(merged.onePercentLowFps, 42.0);
    expect(merged.pointOnePercentLowFps, 31.0);
    expect(merged.gpuLoad, 72.0);
    expect(merged.gpuFrequencyMhz, 900.0);
    expect(merged.gpuFrequencyMaxMhz, 1100.0);
  });

  test('loads customizable square overlay preferences', () {
    final preferences = OverlayPreferences.fromMap({
      'textSizeSp': 18,
      'opacity': 0.7,
      'paddingDp': 4,
      'refreshIntervalMs': 100,
      'showGpuLoad': false,
      'textColorValue': 0xFF39E7D0,
    });
    expect(preferences.textSizeSp, 18);
    expect(preferences.opacity, 0.7);
    expect(preferences.paddingDp, 4);
    expect(preferences.refreshIntervalMs, 100);
    expect(preferences.showGpuLoad, isFalse);
    expect(preferences.textColorValue, 0xFF39E7D0);
  });
}
