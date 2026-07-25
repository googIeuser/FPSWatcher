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
      fpsData: {'averageFps': 59.8, 'p99Fps': 42.0},
      gpuData: {'loadPercent': 72.0, 'frequencyMhz': 900.0},
    );
    expect(merged.fps, 59.8);
    expect(merged.p99Fps, 42.0);
    expect(merged.gpuLoad, 72.0);
    expect(merged.gpuFrequencyMhz, 900.0);
  });
}
