import 'package:flutter_test/flutter_test.dart';
import 'package:fps_watcher/src/models/telemetry_sample.dart';

void main() {
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
}
