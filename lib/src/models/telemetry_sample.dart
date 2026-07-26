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
    this.sampleIntervalMs,
    this.foregroundPackage,
    this.accessModeRequested = 'auto',
    this.accessModeUsed = 'standard',
    this.backendOperational = true,
    this.backendError,
    this.fpsSource,
    this.fps,
    this.onePercentLowFps,
    this.pointOnePercentLowFps,
    this.frameTimeMs,
    this.frameTimeP95Ms,
    this.frameTimeP99Ms,
    this.totalFrames,
    this.cpuUsage,
    this.cpuFrequencyMhz,
    this.cpuFrequencyMinMhz,
    this.cpuFrequencyMaxMhz,
    this.cpuCoreFrequenciesMhz = const <double>[],
    this.cpuGovernor,
    this.appPid,
    this.appCpuUsage,
    this.appRamMb,
    this.appRssMb,
    this.socTemperatureC,
    this.gpuModel,
    this.gpuSource,
    this.gpuFrequencyMhz,
    this.gpuFrequencyMaxMhz,
    this.gpuLoad,
    this.ramUsedMb,
    this.ramTotalMb,
    this.batteryLevel,
    this.batteryTemperatureC,
    this.batteryPowerW,
    this.batteryPowerSource,
    this.batteryCharging,
    this.batteryCurrentMa,
    this.batteryVoltageV,
    this.thermalStatus,
    this.refreshRateHz,
    this.rxKbps,
    this.txKbps,
    this.storageUsedGb,
    this.storageTotalGb,
    this.surfaceFlingerRaw,
    this.gpuRaw,
    this.collectorWarnings = const <String>[],
  });

  final DateTime timestamp;
  final int? sampleIntervalMs;
  final String? foregroundPackage;
  final String accessModeRequested;
  final String accessModeUsed;
  final bool backendOperational;
  final String? backendError;
  final String? fpsSource;
  final double? fps;
  final double? onePercentLowFps;
  final double? pointOnePercentLowFps;
  final double? frameTimeMs;
  final double? frameTimeP95Ms;
  final double? frameTimeP99Ms;
  final int? totalFrames;
  final double? cpuUsage;
  final double? cpuFrequencyMhz;
  final double? cpuFrequencyMinMhz;
  final double? cpuFrequencyMaxMhz;
  final List<double> cpuCoreFrequenciesMhz;
  final String? cpuGovernor;
  final int? appPid;
  final double? appCpuUsage;
  final double? appRamMb;
  final double? appRssMb;
  final double? socTemperatureC;
  final String? gpuModel;
  final String? gpuSource;
  final double? gpuFrequencyMhz;
  final double? gpuFrequencyMaxMhz;
  final double? gpuLoad;
  final double? ramUsedMb;
  final double? ramTotalMb;
  final double? batteryLevel;
  final double? batteryTemperatureC;
  final double? batteryPowerW;
  final String? batteryPowerSource;
  final bool? batteryCharging;
  final double? batteryCurrentMa;
  final double? batteryVoltageV;
  final int? thermalStatus;
  final double? refreshRateHz;
  final double? rxKbps;
  final double? txKbps;
  final double? storageUsedGb;
  final double? storageTotalGb;
  final String? surfaceFlingerRaw;
  final String? gpuRaw;
  final List<String> collectorWarnings;

  static double? _d(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  static int? _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  static List<double> _doubleList(dynamic value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .map(_d)
          .whereType<double>()
          .toList(growable: false);

  factory TelemetrySample.fromNative(Map<dynamic, dynamic> source) {
    return TelemetrySample(
      timestamp: source['timestampMs'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (source['timestampMs'] as num).toInt(),
            )
          : DateTime.now(),
      sampleIntervalMs: _i(source['sampleIntervalMs']),
      foregroundPackage: source['foregroundPackage'] as String?,
      accessModeRequested: (source['accessModeRequested'] as String?) ?? 'auto',
      accessModeUsed: (source['accessModeUsed'] as String?) ?? 'standard',
      backendOperational: source['backendOperational'] != false,
      backendError: source['backendError'] as String?,
      fpsSource: source['fpsSource'] as String?,
      fps: _d(source['fps']),
      onePercentLowFps: _d(source['onePercentLowFps']) ?? _d(source['p99Fps']),
      pointOnePercentLowFps:
          _d(source['pointOnePercentLowFps']) ?? _d(source['p999Fps']),
      frameTimeMs: _d(source['frameTimeMs']),
      frameTimeP95Ms: _d(source['frameTimeP95Ms']),
      frameTimeP99Ms: _d(source['frameTimeP99Ms']),
      totalFrames: _i(source['totalFrames']),
      cpuUsage: _d(source['cpuUsage']),
      cpuFrequencyMhz: _d(source['cpuFrequencyMhz']),
      cpuFrequencyMinMhz: _d(source['cpuFrequencyMinMhz']),
      cpuFrequencyMaxMhz: _d(source['cpuFrequencyMaxMhz']),
      cpuCoreFrequenciesMhz: _doubleList(source['cpuCoreFrequenciesMhz']),
      cpuGovernor: source['cpuGovernor'] as String?,
      appPid: _i(source['appPid']),
      appCpuUsage: _d(source['appCpuUsage']),
      appRamMb: _d(source['appRamMb']),
      appRssMb: _d(source['appRssMb']),
      socTemperatureC: _d(source['socTemperatureC']),
      gpuModel: source['gpuModel'] as String?,
      gpuSource: source['gpuSource'] as String?,
      gpuFrequencyMhz: _d(source['gpuFrequencyMhz']),
      gpuFrequencyMaxMhz: _d(source['gpuFrequencyMaxMhz']),
      gpuLoad: _d(source['gpuLoad']),
      ramUsedMb: _d(source['ramUsedMb']),
      ramTotalMb: _d(source['ramTotalMb']),
      batteryLevel: _d(source['batteryLevel']),
      batteryTemperatureC: _d(source['batteryTemperatureC']),
      batteryPowerW: _d(source['batteryPowerW']),
      batteryPowerSource: source['batteryPowerSource'] as String?,
      batteryCharging: source['batteryCharging'] as bool?,
      batteryCurrentMa: _d(source['batteryCurrentMa']),
      batteryVoltageV: _d(source['batteryVoltageV']),
      thermalStatus: _i(source['thermalStatus']),
      refreshRateHz: _d(source['refreshRateHz']),
      rxKbps: _d(source['rxKbps']),
      txKbps: _d(source['txKbps']),
      storageUsedGb: _d(source['storageUsedGb']),
      storageTotalGb: _d(source['storageTotalGb']),
      surfaceFlingerRaw: source['surfaceFlingerRaw'] as String?,
      gpuRaw: source['gpuRaw'] as String?,
      collectorWarnings:
          (source['collectorWarnings'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => '$value')
              .toList(growable: false),
    );
  }

  TelemetrySample mergeParsed({
    Map<String, dynamic>? fpsData,
    Map<String, dynamic>? gpuData,
  }) {
    return TelemetrySample(
      timestamp: timestamp,
      sampleIntervalMs: sampleIntervalMs,
      foregroundPackage: foregroundPackage,
      accessModeRequested: accessModeRequested,
      accessModeUsed: accessModeUsed,
      backendOperational: backendOperational,
      backendError: backendError,
      fpsSource: (fpsData?['source'] as String?) ?? fpsSource,
      fps: _d(fpsData?['averageFps']) ?? fps,
      onePercentLowFps:
          _d(fpsData?['onePercentLowFps']) ?? onePercentLowFps,
      pointOnePercentLowFps:
          _d(fpsData?['pointOnePercentLowFps']) ?? pointOnePercentLowFps,
      frameTimeMs: _d(fpsData?['frameTimeMs']) ?? frameTimeMs,
      frameTimeP95Ms:
          _d(fpsData?['frameTimeP95Ms']) ?? frameTimeP95Ms,
      frameTimeP99Ms:
          _d(fpsData?['frameTimeP99Ms']) ?? frameTimeP99Ms,
      totalFrames: _i(fpsData?['totalFrames']) ?? totalFrames,
      cpuUsage: cpuUsage,
      cpuFrequencyMhz: cpuFrequencyMhz,
      cpuFrequencyMinMhz: cpuFrequencyMinMhz,
      cpuFrequencyMaxMhz: cpuFrequencyMaxMhz,
      cpuCoreFrequenciesMhz: cpuCoreFrequenciesMhz,
      cpuGovernor: cpuGovernor,
      appPid: appPid,
      appCpuUsage: appCpuUsage,
      appRamMb: appRamMb,
      appRssMb: appRssMb,
      socTemperatureC: socTemperatureC,
      gpuModel: (gpuData?['model'] as String?)?.trim().isNotEmpty == true
          ? gpuData!['model'] as String
          : gpuModel,
      gpuSource: gpuSource,
      gpuFrequencyMhz:
          _d(gpuData?['frequencyMhz']) ?? gpuFrequencyMhz,
      gpuFrequencyMaxMhz:
          _d(gpuData?['maxFrequencyMhz']) ?? gpuFrequencyMaxMhz,
      gpuLoad: _d(gpuData?['loadPercent']) ?? gpuLoad,
      ramUsedMb: ramUsedMb,
      ramTotalMb: ramTotalMb,
      batteryLevel: batteryLevel,
      batteryTemperatureC: batteryTemperatureC,
      batteryPowerW: batteryPowerW,
      batteryPowerSource: batteryPowerSource,
      batteryCharging: batteryCharging,
      batteryCurrentMa: batteryCurrentMa,
      batteryVoltageV: batteryVoltageV,
      thermalStatus: thermalStatus,
      refreshRateHz: refreshRateHz,
      rxKbps: rxKbps,
      txKbps: txKbps,
      storageUsedGb: storageUsedGb,
      storageTotalGb: storageTotalGb,
      surfaceFlingerRaw: surfaceFlingerRaw,
      gpuRaw: gpuRaw,
      collectorWarnings: collectorWarnings,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'sampleIntervalMs': sampleIntervalMs,
        'foregroundPackage': foregroundPackage,
        'accessModeRequested': accessModeRequested,
        'accessMode': accessModeUsed,
        'backendOperational': backendOperational,
        'backendError': backendError,
        'fpsSource': fpsSource,
        'fps': fps,
        'onePercentLowFps': onePercentLowFps,
        'pointOnePercentLowFps': pointOnePercentLowFps,
        'frameTimeMs': frameTimeMs,
        'frameTimeP95Ms': frameTimeP95Ms,
        'frameTimeP99Ms': frameTimeP99Ms,
        'totalFrames': totalFrames,
        'cpuUsage': cpuUsage,
        'cpuFrequencyMhz': cpuFrequencyMhz,
        'cpuFrequencyMinMhz': cpuFrequencyMinMhz,
        'cpuFrequencyMaxMhz': cpuFrequencyMaxMhz,
        'cpuCoreFrequenciesMhz': cpuCoreFrequenciesMhz.join('|'),
        'cpuGovernor': cpuGovernor,
        'appPid': appPid,
        'appCpuUsage': appCpuUsage,
        'appRamMb': appRamMb,
        'appRssMb': appRssMb,
        'socTemperatureC': socTemperatureC,
        'gpuModel': gpuModel,
        'gpuSource': gpuSource,
        'gpuFrequencyMhz': gpuFrequencyMhz,
        'gpuFrequencyMaxMhz': gpuFrequencyMaxMhz,
        'gpuLoad': gpuLoad,
        'ramUsedMb': ramUsedMb,
        'ramTotalMb': ramTotalMb,
        'batteryLevel': batteryLevel,
        'batteryTemperatureC': batteryTemperatureC,
        'batteryPowerW': batteryPowerW,
        'batteryPowerSource': batteryPowerSource,
        'batteryCharging': batteryCharging,
        'batteryCurrentMa': batteryCurrentMa,
        'batteryVoltageV': batteryVoltageV,
        'thermalStatus': thermalStatus,
        'refreshRateHz': refreshRateHz,
        'rxKbps': rxKbps,
        'txKbps': txKbps,
        'storageUsedGb': storageUsedGb,
        'storageTotalGb': storageTotalGb,
      };

  String toJsonString() => jsonEncode(toJson());
}
