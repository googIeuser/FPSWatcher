import 'dart:convert';
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

  List<Map<String, dynamic>> get _rows =>
      _samples.map((sample) => sample.toJson()).toList(growable: false);

  String createCsv() => _rustCore.sessionCsv(_rows) ?? _fallbackCsv(_rows);

  String createJson() => const JsonEncoder.withIndent('  ').convert({
        'schema': 'fpswatcher.session.v4',
        'sampleCount': totalCount,
        'exportedAt': DateTime.now().toIso8601String(),
        'samples': _rows,
      });

  String createHtml() {
    final summary = summarize();
    String f(double? value, [int digits = 1]) =>
        value == null ? '—' : value.toStringAsFixed(digits);
    final rows = _samples.take(5000).map((sample) => '''
<tr>
<td>${sample.timestamp.toIso8601String()}</td>
<td>${sample.foregroundPackage ?? ''}</td>
<td>${f(sample.fps)}</td>
<td>${f(sample.onePercentLowFps)}</td>
<td>${f(sample.frameTimeP99Ms, 2)}</td>
<td>${f(sample.gpuLoad)}</td>
<td>${f(sample.appCpuUsage)}</td>
<td>${f(sample.batteryPowerW, 2)}</td>
<td>${f(sample.batteryTemperatureC)}</td>
</tr>''').join();
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>FPSWatcher Session Report</title>
<style>body{font-family:system-ui;background:#071018;color:#eaf4f7;margin:24px}h1{margin-bottom:4px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:20px 0}.card{background:#0e1a24;border:1px solid #1d3a44;padding:14px}.v{font-size:24px;font-weight:800;color:#39e7d0}table{width:100%;border-collapse:collapse;font-size:12px}th,td{padding:7px;border-bottom:1px solid #20303a;text-align:left}th{position:sticky;top:0;background:#0e1a24}</style>
</head><body><h1>FPSWatcher</h1><div>Session telemetry report · ${DateTime.now().toIso8601String()}</div>
<div class="grid">
<div class="card"><div class="v">${f(summary['averageFps'] as double?)}</div>Average FPS</div>
<div class="card"><div class="v">${f(summary['averageOnePercentLow'] as double?)}</div>Average 1% low</div>
<div class="card"><div class="v">${f(summary['averagePowerW'] as double?, 2)} W</div>Average power</div>
<div class="card"><div class="v">${f(summary['peakBatteryTemperatureC'] as double?)} °C</div>Peak battery temperature</div>
<div class="card"><div class="v">${f(summary['averageStability'] as double?)}%</div>Frame stability</div>
<div class="card"><div class="v">${f(summary['averageFramePacing'] as double?)}%</div>Frame pacing</div>
<div class="card"><div class="v">${f(summary['averagePerformanceStability'] as double?)}%</div>Performance stability</div>
<div class="card"><div class="v">${summary['stutterEvents'] ?? 0}</div>Stutter events</div>
<div class="card"><div class="v">${summary['frozenFrameEvents'] ?? 0}</div>Frozen frames</div>
<div class="card"><div class="v">${f(summary['fpsDriftPercent'] as double?)}%</div>Session FPS drift</div>
</div>
<table><thead><tr><th>Timestamp</th><th>Package</th><th>FPS</th><th>1% low</th><th>P99 ms</th><th>GPU %</th><th>Game CPU %</th><th>W</th><th>Battery °C</th></tr></thead><tbody>$rows</tbody></table>
</body></html>''';
  }

  Map<String, Object?> summarize() {
    double? average(Iterable<double?> source) {
      final values = source.whereType<double>().where((v) => v.isFinite).toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    double? maximum(Iterable<double?> source) {
      final values = source.whereType<double>().where((v) => v.isFinite).toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a > b ? a : b);
    }

    int positiveDeltas(Iterable<int?> source) {
      var previous = 0;
      var total = 0;
      for (final value in source.whereType<int>()) {
        if (value > previous) total += value - previous;
        previous = value;
      }
      return total;
    }

    final metricSamples = _samples.where((s) => s.eventType != 'marker').toList(growable: false);
    final midpoint = metricSamples.length ~/ 2;
    final firstHalf = metricSamples.take(midpoint);
    final secondHalf = metricSamples.skip(midpoint);
    final firstHalfFps = average(firstHalf.map((s) => s.fps));
    final secondHalfFps = average(secondHalf.map((s) => s.fps));
    final firstHalfPower = average(firstHalf.map((s) => s.batteryPowerW));
    final secondHalfPower = average(secondHalf.map((s) => s.batteryPowerW));
    final first = metricSamples.isEmpty ? null : metricSamples.first;
    final last = metricSamples.isEmpty ? null : metricSamples.last;
    return <String, Object?>{
      'averageFps': average(_samples.map((s) => s.fps)),
      'averageFivePercentLow': average(_samples.map((s) => s.fivePercentLowFps)),
      'averageOnePercentLow': average(_samples.map((s) => s.onePercentLowFps)),
      'averagePointOnePercentLow': average(_samples.map((s) => s.pointOnePercentLowFps)),
      'averagePowerW': average(_samples.map((s) => s.batteryPowerW)),
      'peakPowerW': maximum(_samples.map((s) => s.batteryPowerW)),
      'peakBatteryTemperatureC': maximum(_samples.map((s) => s.batteryTemperatureC)),
      'peakSocTemperatureC': maximum(_samples.map((s) => s.socTemperatureC)),
      'averageStability': average(_samples.map((s) => s.frameStabilityScore)),
      'averageFpsPerWatt': average(_samples.map((s) => s.fpsPerWatt)),
      'stutterEvents': positiveDeltas(metricSamples.map((s) => s.stutter25msCount)),
      'frozenFrameEvents': positiveDeltas(metricSamples.map((s) => s.frozenFrameCount)),
      'averageFramePacing': average(metricSamples.map((s) => s.framePacingScore)),
      'averagePerformanceStability': average(metricSamples.map((s) => s.performanceStabilityScore)),
      'firstHalfFps': firstHalfFps,
      'secondHalfFps': secondHalfFps,
      'fpsDriftPercent': firstHalfFps == null || secondHalfFps == null || firstHalfFps == 0
          ? null
          : (secondHalfFps - firstHalfFps) / firstHalfFps * 100.0,
      'firstHalfPowerW': firstHalfPower,
      'secondHalfPowerW': secondHalfPower,
      'thermalThrottleSamples': _samples.where((s) => s.thermalThrottling == true).length,
      'durationSeconds': first == null || last == null
          ? 0
          : last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0,
    };
  }

  String _fallbackCsv(List<Map<String, dynamic>> rows) {
    final headers = <String>{};
    for (final row in rows) {
      headers.addAll(row.keys);
    }
    final ordered = headers.toList(growable: false);
    String cell(Object? value) {
      final text = value?.toString() ?? '';
      return '"${text.replaceAll('"', '""')}"';
    }

    final buffer = StringBuffer()..writeln(ordered.join(','));
    for (final row in rows) {
      buffer.writeln(ordered.map((header) => cell(row[header])).join(','));
    }
    return buffer.toString();
  }
}
