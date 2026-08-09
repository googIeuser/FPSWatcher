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
      'showOnlyWhenGameDetected': false,
    });
    expect(preferences.textSizeSp, 18);
    expect(preferences.opacity, 0.7);
    expect(preferences.paddingDp, 4);
    expect(preferences.refreshIntervalMs, 100);
    expect(preferences.showGpuLoad, isFalse);
    expect(preferences.textColorValue, 0xFF39E7D0);
    expect(preferences.showOnlyWhenGameDetected, isFalse);
  });
  test('accepts mixed persisted value types without crashing', () {
    final sample = TelemetrySample.fromNative({
      'timestampMs': '1700000000000',
      'backendOperational': 1,
      'batteryCharging': 'false',
      'cpuCoreFrequenciesMhz': ['3302.4', 3129.6, null, 'bad'],
      'collectorWarnings': ['one', 2],
      'frameWindowFrames': '840',
    });
    expect(sample.backendOperational, isTrue);
    expect(sample.batteryCharging, isFalse);
    expect(sample.cpuCoreFrequenciesMhz, [3302.4, 3129.6]);
    expect(sample.collectorWarnings, ['one', '2']);
    expect(sample.frameWindowFrames, 840);
  });

  test('keeps native metrics authoritative over parser fallback', () {
    final sample = TelemetrySample.fromNative({
      'fps': 120.0,
      'gpuLoad': 81.0,
      'frameTimeMs': 8.33,
    }).mergeParsed(
      fpsData: {'averageFps': 60.0, 'frameTimeMs': 16.67},
      gpuData: {'loadPercent': 20.0},
    );
    expect(sample.fps, 120.0);
    expect(sample.frameTimeMs, 8.33);
    expect(sample.gpuLoad, 81.0);
  });

  test('normalizes unsupported overlay preference values', () {
    final preferences = OverlayPreferences.fromMap({
      'refreshIntervalMs': 320,
      'textColorValue': 123,
      'opacity': '0.05',
      'showGpuLoad': 'false',
    });
    expect(preferences.refreshIntervalMs, 200);
    expect(preferences.textColorValue, 0xFFFFFFFF);
    expect(preferences.opacity, 0.15);
    expect(preferences.showGpuLoad, isFalse);
  });


  test('parses advanced telemetry fields and frame histogram safely', () {
    final sample = TelemetrySample.fromNative({
      'foregroundIsGame': true,
      'framePacingScore': 94.2,
      'frameHistogramMs': [
        [8, 100],
        ['16.0', '20'],
        ['bad'],
      ],
      'cpuCoreUsagePercent': [20, 40.5],
      'cpuTemperatureC': 47.2,
      'gpuTemperatureC': '44.1',
      'cellularNetworkType': 'NR',
      'windowWidthPx': 2400,
      'windowHeightPx': '1080',
    });
    expect(sample.foregroundIsGame, isTrue);
    expect(sample.framePacingScore, 94.2);
    expect(sample.frameHistogramMs, [
      [8.0, 100.0],
      [16.0, 20.0],
    ]);
    expect(sample.cpuCoreUsagePercent, [20.0, 40.5]);
    expect(sample.cpuTemperatureC, 47.2);
    expect(sample.gpuTemperatureC, 44.1);
    expect(sample.cellularNetworkType, 'NR');
    expect(sample.windowWidthPx, 2400);
    expect(sample.windowHeightPx, 1080);
  });

  test('advanced overlay presets expose focused metric groups', () {
    final base = const OverlayPreferences();
    final performance = base.preset('performance');
    final battery = base.preset('battery');
    final full = base.preset('full');
    expect(performance.showLows, isTrue);
    expect(performance.showGpuLoad, isTrue);
    expect(performance.showDroppedFrames, isTrue);
    expect(battery.showPower, isTrue);
    expect(battery.showEfficiency, isTrue);
    expect(battery.showBatteryDrain, isTrue);
    expect(full.showCpuCores, isTrue);
    expect(full.showProcessDetails, isTrue);
    expect(full.showMonitorOverhead, isTrue);
  });

}
