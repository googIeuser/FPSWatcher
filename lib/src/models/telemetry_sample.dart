import 'dart:convert';

enum AccessMode { shizuku, root }

extension AccessModeX on AccessMode {
  String get wireName => name;
  String get label => switch (this) {
        AccessMode.shizuku => 'Shizuku',
        AccessMode.root => 'Root',
      };
}

class TelemetrySample {
  const TelemetrySample({
    required this.timestamp,
    this.sampleIntervalMs,
    this.foregroundPackage,
    this.accessModeRequested = 'shizuku',
    this.accessModeUsed = 'shizuku',
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
    this.frameWindowFrames,
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
  final int? frameWindowFrames;
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

  static double? _d(dynamic value) {
    if (value == null) return null;
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  static int? _i(dynamic value) {
    if (value == null) return null;
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  static String? _s(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static bool? _b(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return switch ('$value'.trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => null,
    };
  }

  static List<dynamic> _list(dynamic value) =>
      value is List ? value.cast<dynamic>() : const <dynamic>[];

  static List<double> _doubleList(dynamic value) =>
      _list(value).map(_d).whereType<double>().toList(growable: false);

  factory TelemetrySample.fromNative(Map<dynamic, dynamic> source) {
    final timestampMs = _i(source['timestampMs']);
    return TelemetrySample(
      timestamp: timestampMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      sampleIntervalMs: _i(source['sampleIntervalMs']),
      foregroundPackage: _s(source['foregroundPackage']),
      accessModeRequested: _s(source['accessModeRequested']) ?? 'shizuku',
      accessModeUsed: _s(source['accessModeUsed']) ?? 'shizuku',
      backendOperational: _b(source['backendOperational']) ?? true,
      backendError: _s(source['backendError']),
      fpsSource: _s(source['fpsSource']),
      fps: _d(source['fps']),
      onePercentLowFps: _d(source['onePercentLowFps']) ?? _d(source['p99Fps']),
      pointOnePercentLowFps:
          _d(source['pointOnePercentLowFps']) ?? _d(source['p999Fps']),
      frameTimeMs: _d(source['frameTimeMs']),
      frameTimeP95Ms: _d(source['frameTimeP95Ms']),
      frameTimeP99Ms: _d(source['frameTimeP99Ms']),
      totalFrames: _i(source['totalFrames']),
      frameWindowFrames: _i(source['frameWindowFrames']),
      cpuUsage: _d(source['cpuUsage']),
      cpuFrequencyMhz: _d(source['cpuFrequencyMhz']),
      cpuFrequencyMinMhz: _d(source['cpuFrequencyMinMhz']),
      cpuFrequencyMaxMhz: _d(source['cpuFrequencyMaxMhz']),
      cpuCoreFrequenciesMhz: _doubleList(source['cpuCoreFrequenciesMhz']),
      cpuGovernor: _s(source['cpuGovernor']),
      appPid: _i(source['appPid']),
      appCpuUsage: _d(source['appCpuUsage']),
      appRamMb: _d(source['appRamMb']),
      appRssMb: _d(source['appRssMb']),
      socTemperatureC: _d(source['socTemperatureC']),
      gpuModel: _s(source['gpuModel']),
      gpuSource: _s(source['gpuSource']),
      gpuFrequencyMhz: _d(source['gpuFrequencyMhz']),
      gpuFrequencyMaxMhz: _d(source['gpuFrequencyMaxMhz']),
      gpuLoad: _d(source['gpuLoad']),
      ramUsedMb: _d(source['ramUsedMb']),
      ramTotalMb: _d(source['ramTotalMb']),
      batteryLevel: _d(source['batteryLevel']),
      batteryTemperatureC: _d(source['batteryTemperatureC']),
      batteryPowerW: _d(source['batteryPowerW']),
      batteryPowerSource: _s(source['batteryPowerSource']),
      batteryCharging: _b(source['batteryCharging']),
      batteryCurrentMa: _d(source['batteryCurrentMa']),
      batteryVoltageV: _d(source['batteryVoltageV']),
      thermalStatus: _i(source['thermalStatus']),
      refreshRateHz: _d(source['refreshRateHz']),
      rxKbps: _d(source['rxKbps']),
      txKbps: _d(source['txKbps']),
      storageUsedGb: _d(source['storageUsedGb']),
      storageTotalGb: _d(source['storageTotalGb']),
      surfaceFlingerRaw: _s(source['surfaceFlingerRaw']),
      gpuRaw: _s(source['gpuRaw']),
      collectorWarnings:
          _list(source['collectorWarnings'])
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
      fpsSource: fpsSource ?? _s(fpsData?['source']),
      fps: fps ?? _d(fpsData?['averageFps']),
      onePercentLowFps:
          onePercentLowFps ?? _d(fpsData?['onePercentLowFps']),
      pointOnePercentLowFps:
          pointOnePercentLowFps ?? _d(fpsData?['pointOnePercentLowFps']),
      frameTimeMs: frameTimeMs ?? _d(fpsData?['frameTimeMs']),
      frameTimeP95Ms:
          frameTimeP95Ms ?? _d(fpsData?['frameTimeP95Ms']),
      frameTimeP99Ms:
          frameTimeP99Ms ?? _d(fpsData?['frameTimeP99Ms']),
      totalFrames: totalFrames ?? _i(fpsData?['totalFrames']),
      frameWindowFrames: frameWindowFrames ?? _i(fpsData?['frameWindowFrames']),
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
      gpuModel: gpuModel ?? _s(gpuData?['model']),
      gpuSource: gpuSource,
      gpuFrequencyMhz:
          gpuFrequencyMhz ?? _d(gpuData?['frequencyMhz']),
      gpuFrequencyMaxMhz:
          gpuFrequencyMaxMhz ?? _d(gpuData?['maxFrequencyMhz']),
      gpuLoad: gpuLoad ?? _d(gpuData?['loadPercent']),
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
        'frameWindowFrames': frameWindowFrames,
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
