import 'dart:convert';

enum AccessMode { auto, standard, shizuku, root }

extension AccessModeX on AccessMode {
  String get wireName => name;
  String get label => switch (this) {
        AccessMode.auto => 'Auto',
        AccessMode.standard => 'Standard',
        AccessMode.shizuku => 'Shizuku',
        AccessMode.root => 'Root',
      };
}

class TelemetrySample {
  const TelemetrySample({
    required this.timestamp,
    this.foregroundPackage,
    this.accessModeUsed = 'standard',
    this.fps,
    this.p90Fps,
    this.p99Fps,
    this.frameTimeMs,
    this.totalFrames,
    this.cpuUsage,
    this.cpuFrequencyMhz,
    this.appPid,
    this.appCpuUsage,
    this.appRamMb,
    this.socTemperatureC,
    this.gpuModel,
    this.gpuFrequencyMhz,
    this.gpuLoad,
    this.ramUsedMb,
    this.ramTotalMb,
    this.batteryLevel,
    this.batteryTemperatureC,
    this.batteryPowerW,
    this.thermalStatus,
    this.refreshRateHz,
    this.rxKbps,
    this.txKbps,
    this.storageUsedGb,
    this.storageTotalGb,
    this.surfaceFlingerRaw,
    this.gpuRaw,
  });

  final DateTime timestamp;
  final String? foregroundPackage;
  final String accessModeUsed;
  final double? fps;
  final double? p90Fps;
  final double? p99Fps;
  final double? frameTimeMs;
  final int? totalFrames;
  final double? cpuUsage;
  final double? cpuFrequencyMhz;
  final int? appPid;
  final double? appCpuUsage;
  final double? appRamMb;
  final double? socTemperatureC;
  final String? gpuModel;
  final double? gpuFrequencyMhz;
  final double? gpuLoad;
  final double? ramUsedMb;
  final double? ramTotalMb;
  final double? batteryLevel;
  final double? batteryTemperatureC;
  final double? batteryPowerW;
  final int? thermalStatus;
  final double? refreshRateHz;
  final double? rxKbps;
  final double? txKbps;
  final double? storageUsedGb;
  final double? storageTotalGb;
  final String? surfaceFlingerRaw;
  final String? gpuRaw;

  static double? _d(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
  static int? _i(dynamic value) => value is num ? value.toInt() : int.tryParse('$value');

  factory TelemetrySample.fromNative(Map<dynamic, dynamic> source) {
    return TelemetrySample(
      timestamp: source['timestampMs'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (source['timestampMs'] as num).toInt(),
            )
          : DateTime.now(),
      foregroundPackage: source['foregroundPackage'] as String?,
      accessModeUsed: (source['accessModeUsed'] as String?) ?? 'standard',
      fps: _d(source['fps']),
      p90Fps: _d(source['p90Fps']),
      p99Fps: _d(source['p99Fps']),
      frameTimeMs: _d(source['frameTimeMs']),
      totalFrames: _i(source['totalFrames']),
      cpuUsage: _d(source['cpuUsage']),
      cpuFrequencyMhz: _d(source['cpuFrequencyMhz']),
      appPid: _i(source['appPid']),
      appCpuUsage: _d(source['appCpuUsage']),
      appRamMb: _d(source['appRamMb']),
      socTemperatureC: _d(source['socTemperatureC']),
      gpuModel: source['gpuModel'] as String?,
      gpuFrequencyMhz: _d(source['gpuFrequencyMhz']),
      gpuLoad: _d(source['gpuLoad']),
      ramUsedMb: _d(source['ramUsedMb']),
      ramTotalMb: _d(source['ramTotalMb']),
      batteryLevel: _d(source['batteryLevel']),
      batteryTemperatureC: _d(source['batteryTemperatureC']),
      batteryPowerW: _d(source['batteryPowerW']),
      thermalStatus: _i(source['thermalStatus']),
      refreshRateHz: _d(source['refreshRateHz']),
      rxKbps: _d(source['rxKbps']),
      txKbps: _d(source['txKbps']),
      storageUsedGb: _d(source['storageUsedGb']),
      storageTotalGb: _d(source['storageTotalGb']),
      surfaceFlingerRaw: source['surfaceFlingerRaw'] as String?,
      gpuRaw: source['gpuRaw'] as String?,
    );
  }

  TelemetrySample mergeParsed({Map<String, dynamic>? fpsData, Map<String, dynamic>? gpuData}) {
    return TelemetrySample(
      timestamp: timestamp,
      foregroundPackage: foregroundPackage,
      accessModeUsed: accessModeUsed,
      fps: _d(fpsData?['averageFps']) ?? fps,
      p90Fps: _d(fpsData?['p90Fps']) ?? p90Fps,
      p99Fps: _d(fpsData?['p99Fps']) ?? p99Fps,
      frameTimeMs: _d(fpsData?['frameTimeMs']) ?? frameTimeMs,
      totalFrames: _i(fpsData?['totalFrames']) ?? totalFrames,
      cpuUsage: cpuUsage,
      cpuFrequencyMhz: cpuFrequencyMhz,
      appPid: appPid,
      appCpuUsage: appCpuUsage,
      appRamMb: appRamMb,
      socTemperatureC: socTemperatureC,
      gpuModel: (gpuData?['model'] as String?)?.trim().isNotEmpty == true
          ? gpuData!['model'] as String
          : gpuModel,
      gpuFrequencyMhz: _d(gpuData?['frequencyMhz']) ?? gpuFrequencyMhz,
      gpuLoad: _d(gpuData?['loadPercent']) ?? gpuLoad,
      ramUsedMb: ramUsedMb,
      ramTotalMb: ramTotalMb,
      batteryLevel: batteryLevel,
      batteryTemperatureC: batteryTemperatureC,
      batteryPowerW: batteryPowerW,
      thermalStatus: thermalStatus,
      refreshRateHz: refreshRateHz,
      rxKbps: rxKbps,
      txKbps: txKbps,
      storageUsedGb: storageUsedGb,
      storageTotalGb: storageTotalGb,
      surfaceFlingerRaw: surfaceFlingerRaw,
      gpuRaw: gpuRaw,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'foregroundPackage': foregroundPackage,
        'accessMode': accessModeUsed,
        'fps': fps,
        'p90Fps': p90Fps,
        'p99Fps': p99Fps,
        'frameTimeMs': frameTimeMs,
        'totalFrames': totalFrames,
        'cpuUsage': cpuUsage,
        'cpuFrequencyMhz': cpuFrequencyMhz,
        'appPid': appPid,
        'appCpuUsage': appCpuUsage,
        'appRamMb': appRamMb,
        'socTemperatureC': socTemperatureC,
        'gpuModel': gpuModel,
        'gpuFrequencyMhz': gpuFrequencyMhz,
        'gpuLoad': gpuLoad,
        'ramUsedMb': ramUsedMb,
        'ramTotalMb': ramTotalMb,
        'batteryLevel': batteryLevel,
        'batteryTemperatureC': batteryTemperatureC,
        'batteryPowerW': batteryPowerW,
        'thermalStatus': thermalStatus,
        'refreshRateHz': refreshRateHz,
        'rxKbps': rxKbps,
        'txKbps': txKbps,
        'storageUsedGb': storageUsedGb,
        'storageTotalGb': storageTotalGb,
      };

  String toJsonString() => jsonEncode(toJson());
}
