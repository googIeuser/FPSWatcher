import '../models/telemetry_sample.dart';
import 'rust_core.dart';

class SessionRecorder {
  SessionRecorder(this._rustCore);

  final RustCore _rustCore;
  final List<TelemetrySample> _samples = [];
  bool isRecording = false;
  DateTime? startedAt;
  int totalCount = 0;

  List<TelemetrySample> get samples => List.unmodifiable(_samples);

  void start() {
    _samples.clear();
    totalCount = 0;
    startedAt = DateTime.now();
    isRecording = true;
  }

  void stop() => isRecording = false;

  void restoreState({required bool recording, required int count}) {
    isRecording = recording;
    totalCount = count;
    if (recording && startedAt == null) startedAt = DateTime.now();
  }

  void replaceSamples(
    List<TelemetrySample> samples, {
    required int totalCount,
    required bool recording,
  }) {
    _samples
      ..clear()
      ..addAll(samples);
    this.totalCount = totalCount;
    isRecording = recording;
    if (recording && startedAt == null) startedAt = DateTime.now();
  }

  String createCsv() {
    final data = _samples
        .map((sample) => sample.toJson())
        .toList(growable: false);
    return _rustCore.sessionCsv(data) ?? _fallbackCsv(data);
  }

  String _fallbackCsv(List<Map<String, dynamic>> rows) {
    const headers = <String>[
      'timestamp',
      'foregroundPackage',
      'accessMode',
      'fps',
      'p90Fps',
      'p99Fps',
      'frameTimeMs',
      'totalFrames',
      'cpuUsage',
      'cpuFrequencyMhz',
      'appPid',
      'appCpuUsage',
      'appRamMb',
      'socTemperatureC',
      'gpuModel',
      'gpuFrequencyMhz',
      'gpuLoad',
      'ramUsedMb',
      'ramTotalMb',
      'batteryLevel',
      'batteryTemperatureC',
      'batteryPowerW',
      'thermalStatus',
      'refreshRateHz',
      'rxKbps',
      'txKbps',
      'storageUsedGb',
      'storageTotalGb',
    ];
    String cell(Object? value) {
      final text = value?.toString() ?? '';
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }

    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final row in rows) {
      buffer.writeln(headers.map((header) => cell(row[header])).join(','));
    }
    return buffer.toString();
  }
}
