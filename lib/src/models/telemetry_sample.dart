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
    this.foregroundIsGame,
    this.eventType,
    this.eventLabel,
    this.accessModeRequested = 'shizuku',
    this.accessModeUsed = 'shizuku',
    this.backendOperational = true,
    this.backendError,
    this.fpsSource,
    this.fps,
    this.fivePercentLowFps,
    this.onePercentLowFps,
    this.pointOnePercentLowFps,
    this.medianFps,
    this.minimumInstantFps,
    this.maximumInstantFps,
    this.frameTimeMs,
    this.frameTimeP95Ms,
    this.frameTimeP99Ms,
    this.bestFrameTimeMs,
    this.worstFrameTimeMs,
    this.frameStabilityScore,
    this.framePacingScore,
    this.performanceStabilityScore,
    this.stutter25msCount,
    this.stutter50msCount,
    this.stutter100msCount,
    this.microStutterCount,
    this.slowFrameCount,
    this.frozenFrameCount,
    this.estimatedDroppedFrames,
    this.missedVsyncCount,
    this.refreshRateMismatch,
    this.fpsRefreshRatio,
    this.totalFrames,
    this.frameWindowFrames,
    this.frameHistogramMs = const <List<double>>[],
    this.cpuUsage,
    this.cpuFrequencyMhz,
    this.cpuFrequencyMinMhz,
    this.cpuFrequencyMaxMhz,
    this.cpuPolicyMinMhz,
    this.cpuPolicyMaxMhz,
    this.cpuPolicyAverageMaxMhz,
    this.cpuCoreFrequenciesMhz = const <double>[],
    this.cpuCoreUsagePercent = const <double>[],
    this.cpuGovernor,
    this.cpuClusterSummary,
    this.cpuThrottlePercent,
    this.cpuThrottled,
    this.appPid,
    this.appCpuUsage,
    this.appRamMb,
    this.appRssMb,
    this.appNativeHeapMb,
    this.appGraphicsMb,
    this.appThreadCount,
    this.appNice,
    this.appCpuset,
    this.appUclampMin,
    this.appUclampMax,
    this.appCpuAffinity,
    this.appSchedulerPolicy,
    this.graphicsApi,
    this.gameModeInfo,
    this.socTemperatureC,
    this.cpuTemperatureC,
    this.gpuTemperatureC,
    this.thermalThrottling,
    this.thermalStabilityScore,
    this.thermalZonesRaw,
    this.gpuModel,
    this.gpuVendor,
    this.gpuSource,
    this.gpuFrequencyMhz,
    this.gpuFrequencyMinMhz,
    this.gpuFrequencyMaxMhz,
    this.gpuGovernor,
    this.gpuLoad,
    this.gpuThrottlePercent,
    this.gpuThrottled,
    this.ramUsedMb,
    this.ramTotalMb,
    this.ramAvailableMb,
    this.swapUsedMb,
    this.swapTotalMb,
    this.zramUsedMb,
    this.memoryPressureAvg10,
    this.batteryLevel,
    this.batteryTemperatureC,
    this.batteryPowerW,
    this.batteryPowerSource,
    this.batteryCharging,
    this.batteryCurrentMa,
    this.batteryVoltageV,
    this.batteryChargeCounterMah,
    this.batteryDrainPercentPerHour,
    this.batteryDrainMahPerHour,
    this.estimatedGamingMinutes,
    this.fpsPerWatt,
    this.thermalStatus,
    this.refreshRateHz,
    this.networkType,
    this.rxKbps,
    this.txKbps,
    this.networkPingMs,
    this.networkJitterMs,
    this.networkPacketLossPercent,
    this.networkProbeTarget,
    this.wifiRssiDbm,
    this.wifiLinkSpeedMbps,
    this.wifiFrequencyMhz,
    this.wifiStandard,
    this.cellularNetworkType,
    this.cellularSignalSummary,
    this.windowWidthPx,
    this.windowHeightPx,
    this.storageUsedGb,
    this.storageTotalGb,
    this.collectorLatencyMs,
    this.monitorCpuUsage,
    this.monitorRamMb,
    this.surfaceFlingerRaw,
    this.gpuRaw,
    this.collectorWarnings = const <String>[],
  });

  final DateTime timestamp;
  final int? sampleIntervalMs;
  final String? foregroundPackage;
  final bool? foregroundIsGame;
  final String? eventType;
  final String? eventLabel;
  final String accessModeRequested;
  final String accessModeUsed;
  final bool backendOperational;
  final String? backendError;

  final String? fpsSource;
  final double? fps;
  final double? fivePercentLowFps;
  final double? onePercentLowFps;
  final double? pointOnePercentLowFps;
  final double? medianFps;
  final double? minimumInstantFps;
  final double? maximumInstantFps;
  final double? frameTimeMs;
  final double? frameTimeP95Ms;
  final double? frameTimeP99Ms;
  final double? bestFrameTimeMs;
  final double? worstFrameTimeMs;
  final double? frameStabilityScore;
  final double? framePacingScore;
  final double? performanceStabilityScore;
  final int? stutter25msCount;
  final int? stutter50msCount;
  final int? stutter100msCount;
  final int? microStutterCount;
  final int? slowFrameCount;
  final int? frozenFrameCount;
  final int? estimatedDroppedFrames;
  final int? missedVsyncCount;
  final bool? refreshRateMismatch;
  final double? fpsRefreshRatio;
  final int? totalFrames;
  final int? frameWindowFrames;
  final List<List<double>> frameHistogramMs;

  final double? cpuUsage;
  final double? cpuFrequencyMhz;
  final double? cpuFrequencyMinMhz;
  final double? cpuFrequencyMaxMhz;
  final double? cpuPolicyMinMhz;
  final double? cpuPolicyMaxMhz;
  final double? cpuPolicyAverageMaxMhz;
  final List<double> cpuCoreFrequenciesMhz;
  final List<double> cpuCoreUsagePercent;
  final String? cpuGovernor;
  final String? cpuClusterSummary;
  final double? cpuThrottlePercent;
  final bool? cpuThrottled;

  final int? appPid;
  final double? appCpuUsage;
  final double? appRamMb;
  final double? appRssMb;
  final double? appNativeHeapMb;
  final double? appGraphicsMb;
  final int? appThreadCount;
  final int? appNice;
  final String? appCpuset;
  final double? appUclampMin;
  final double? appUclampMax;
  final String? appCpuAffinity;
  final String? appSchedulerPolicy;
  final String? graphicsApi;
  final String? gameModeInfo;

  final double? socTemperatureC;
  final double? cpuTemperatureC;
  final double? gpuTemperatureC;
  final bool? thermalThrottling;
  final double? thermalStabilityScore;
  final String? thermalZonesRaw;

  final String? gpuModel;
  final String? gpuVendor;
  final String? gpuSource;
  final double? gpuFrequencyMhz;
  final double? gpuFrequencyMinMhz;
  final double? gpuFrequencyMaxMhz;
  final String? gpuGovernor;
  final double? gpuLoad;
  final double? gpuThrottlePercent;
  final bool? gpuThrottled;

  final double? ramUsedMb;
  final double? ramTotalMb;
  final double? ramAvailableMb;
  final double? swapUsedMb;
  final double? swapTotalMb;
  final double? zramUsedMb;
  final double? memoryPressureAvg10;

  final double? batteryLevel;
  final double? batteryTemperatureC;
  final double? batteryPowerW;
  final String? batteryPowerSource;
  final bool? batteryCharging;
  final double? batteryCurrentMa;
  final double? batteryVoltageV;
  final double? batteryChargeCounterMah;
  final double? batteryDrainPercentPerHour;
  final double? batteryDrainMahPerHour;
  final double? estimatedGamingMinutes;
  final double? fpsPerWatt;

  final int? thermalStatus;
  final double? refreshRateHz;
  final String? networkType;
  final double? rxKbps;
  final double? txKbps;
  final double? networkPingMs;
  final double? networkJitterMs;
  final double? networkPacketLossPercent;
  final String? networkProbeTarget;
  final int? wifiRssiDbm;
  final double? wifiLinkSpeedMbps;
  final double? wifiFrequencyMhz;
  final String? wifiStandard;
  final String? cellularNetworkType;
  final String? cellularSignalSummary;
  final int? windowWidthPx;
  final int? windowHeightPx;
  final double? storageUsedGb;
  final double? storageTotalGb;

  final double? collectorLatencyMs;
  final double? monitorCpuUsage;
  final double? monitorRamMb;
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

  static List<List<double>> _doublePairs(dynamic value) => _list(value)
      .map((item) => _doubleList(item))
      .where((item) => item.length >= 2)
      .map((item) => <double>[item[0], item[1]])
      .toList(growable: false);

  static String? _gpuVendor(String? model) {
    final value = model?.toLowerCase() ?? '';
    if (value.contains('adreno') || value.contains('qualcomm')) return 'Qualcomm';
    if (value.contains('mali') || value.contains('immortalis')) return 'Arm';
    if (value.contains('powervr') || value.contains('pvr')) return 'Imagination';
    return value.isEmpty ? null : 'Unknown';
  }

  factory TelemetrySample.fromNative(Map<dynamic, dynamic> source) {
    final timestampMs = _i(source['timestampMs']);
    return TelemetrySample(
      timestamp: timestampMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      sampleIntervalMs: _i(source['sampleIntervalMs']),
      foregroundPackage: _s(source['foregroundPackage']),
      foregroundIsGame: _b(source['foregroundIsGame']),
      eventType: _s(source['eventType']),
      eventLabel: _s(source['eventLabel']),
      accessModeRequested: _s(source['accessModeRequested']) ?? 'shizuku',
      accessModeUsed: _s(source['accessModeUsed']) ?? 'shizuku',
      backendOperational: _b(source['backendOperational']) ?? true,
      backendError: _s(source['backendError']),
      fpsSource: _s(source['fpsSource']),
      fps: _d(source['fps']),
      fivePercentLowFps: _d(source['fivePercentLowFps']),
      onePercentLowFps: _d(source['onePercentLowFps']) ?? _d(source['p99Fps']),
      pointOnePercentLowFps:
          _d(source['pointOnePercentLowFps']) ?? _d(source['p999Fps']),
      medianFps: _d(source['medianFps']),
      minimumInstantFps: _d(source['minimumInstantFps']),
      maximumInstantFps: _d(source['maximumInstantFps']),
      frameTimeMs: _d(source['frameTimeMs']),
      frameTimeP95Ms: _d(source['frameTimeP95Ms']),
      frameTimeP99Ms: _d(source['frameTimeP99Ms']),
      bestFrameTimeMs: _d(source['bestFrameTimeMs']),
      worstFrameTimeMs: _d(source['worstFrameTimeMs']),
      frameStabilityScore: _d(source['frameStabilityScore']),
      framePacingScore: _d(source['framePacingScore']),
      performanceStabilityScore: _d(source['performanceStabilityScore']),
      stutter25msCount: _i(source['stutter25msCount']),
      stutter50msCount: _i(source['stutter50msCount']),
      stutter100msCount: _i(source['stutter100msCount']),
      microStutterCount: _i(source['microStutterCount']),
      slowFrameCount: _i(source['slowFrameCount']),
      frozenFrameCount: _i(source['frozenFrameCount']),
      estimatedDroppedFrames: _i(source['estimatedDroppedFrames']),
      missedVsyncCount: _i(source['missedVsyncCount']),
      refreshRateMismatch: _b(source['refreshRateMismatch']),
      fpsRefreshRatio: _d(source['fpsRefreshRatio']),
      totalFrames: _i(source['totalFrames']),
      frameWindowFrames: _i(source['frameWindowFrames']),
      frameHistogramMs: _doublePairs(source['frameHistogramMs']),
      cpuUsage: _d(source['cpuUsage']),
      cpuFrequencyMhz: _d(source['cpuFrequencyMhz']),
      cpuFrequencyMinMhz: _d(source['cpuFrequencyMinMhz']),
      cpuFrequencyMaxMhz: _d(source['cpuFrequencyMaxMhz']),
      cpuPolicyMinMhz: _d(source['cpuPolicyMinMhz']),
      cpuPolicyMaxMhz: _d(source['cpuPolicyMaxMhz']),
      cpuPolicyAverageMaxMhz: _d(source['cpuPolicyAverageMaxMhz']),
      cpuCoreFrequenciesMhz: _doubleList(source['cpuCoreFrequenciesMhz']),
      cpuCoreUsagePercent: _doubleList(source['cpuCoreUsagePercent']),
      cpuGovernor: _s(source['cpuGovernor']),
      cpuClusterSummary: _s(source['cpuClusterSummary']),
      cpuThrottlePercent: _d(source['cpuThrottlePercent']),
      cpuThrottled: _b(source['cpuThrottled']),
      appPid: _i(source['appPid']),
      appCpuUsage: _d(source['appCpuUsage']),
      appRamMb: _d(source['appRamMb']),
      appRssMb: _d(source['appRssMb']),
      appNativeHeapMb: _d(source['appNativeHeapMb']),
      appGraphicsMb: _d(source['appGraphicsMb']),
      appThreadCount: _i(source['appThreadCount']),
      appNice: _i(source['appNice']),
      appCpuset: _s(source['appCpuset']),
      appUclampMin: _d(source['appUclampMin']),
      appUclampMax: _d(source['appUclampMax']),
      appCpuAffinity: _s(source['appCpuAffinity']),
      appSchedulerPolicy: _s(source['appSchedulerPolicy']),
      graphicsApi: _s(source['graphicsApi']),
      gameModeInfo: _s(source['gameModeInfo']),
      socTemperatureC: _d(source['socTemperatureC']),
      cpuTemperatureC: _d(source['cpuTemperatureC']),
      gpuTemperatureC: _d(source['gpuTemperatureC']),
      thermalThrottling: _b(source['thermalThrottling']),
      thermalStabilityScore: _d(source['thermalStabilityScore']),
      thermalZonesRaw: _s(source['thermalZonesRaw']),
      gpuModel: _s(source['gpuModel']),
      gpuVendor: _s(source['gpuVendor']),
      gpuSource: _s(source['gpuSource']),
      gpuFrequencyMhz: _d(source['gpuFrequencyMhz']),
      gpuFrequencyMinMhz: _d(source['gpuFrequencyMinMhz']),
      gpuFrequencyMaxMhz: _d(source['gpuFrequencyMaxMhz']),
      gpuGovernor: _s(source['gpuGovernor']),
      gpuLoad: _d(source['gpuLoad']),
      gpuThrottlePercent: _d(source['gpuThrottlePercent']),
      gpuThrottled: _b(source['gpuThrottled']),
      ramUsedMb: _d(source['ramUsedMb']),
      ramTotalMb: _d(source['ramTotalMb']),
      ramAvailableMb: _d(source['ramAvailableMb']),
      swapUsedMb: _d(source['swapUsedMb']),
      swapTotalMb: _d(source['swapTotalMb']),
      zramUsedMb: _d(source['zramUsedMb']),
      memoryPressureAvg10: _d(source['memoryPressureAvg10']),
      batteryLevel: _d(source['batteryLevel']),
      batteryTemperatureC: _d(source['batteryTemperatureC']),
      batteryPowerW: _d(source['batteryPowerW']),
      batteryPowerSource: _s(source['batteryPowerSource']),
      batteryCharging: _b(source['batteryCharging']),
      batteryCurrentMa: _d(source['batteryCurrentMa']),
      batteryVoltageV: _d(source['batteryVoltageV']),
      batteryChargeCounterMah: _d(source['batteryChargeCounterMah']),
      batteryDrainPercentPerHour: _d(source['batteryDrainPercentPerHour']),
      batteryDrainMahPerHour: _d(source['batteryDrainMahPerHour']),
      estimatedGamingMinutes: _d(source['estimatedGamingMinutes']),
      fpsPerWatt: _d(source['fpsPerWatt']),
      thermalStatus: _i(source['thermalStatus']),
      refreshRateHz: _d(source['refreshRateHz']),
      networkType: _s(source['networkType']),
      rxKbps: _d(source['rxKbps']),
      txKbps: _d(source['txKbps']),
      networkPingMs: _d(source['networkPingMs']),
      networkJitterMs: _d(source['networkJitterMs']),
      networkPacketLossPercent: _d(source['networkPacketLossPercent']),
      networkProbeTarget: _s(source['networkProbeTarget']),
      wifiRssiDbm: _i(source['wifiRssiDbm']),
      wifiLinkSpeedMbps: _d(source['wifiLinkSpeedMbps']),
      wifiFrequencyMhz: _d(source['wifiFrequencyMhz']),
      wifiStandard: _s(source['wifiStandard']),
      cellularNetworkType: _s(source['cellularNetworkType']),
      cellularSignalSummary: _s(source['cellularSignalSummary']),
      windowWidthPx: _i(source['windowWidthPx']),
      windowHeightPx: _i(source['windowHeightPx']),
      storageUsedGb: _d(source['storageUsedGb']),
      storageTotalGb: _d(source['storageTotalGb']),
      collectorLatencyMs: _d(source['collectorLatencyMs']),
      monitorCpuUsage: _d(source['monitorCpuUsage']),
      monitorRamMb: _d(source['monitorRamMb']),
      surfaceFlingerRaw: _s(source['surfaceFlingerRaw']),
      gpuRaw: _s(source['gpuRaw']),
      collectorWarnings: _list(source['collectorWarnings'])
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
      foregroundIsGame: foregroundIsGame,
      eventType: eventType,
      eventLabel: eventLabel,
      accessModeRequested: accessModeRequested,
      accessModeUsed: accessModeUsed,
      backendOperational: backendOperational,
      backendError: backendError,
      fpsSource: fpsSource ?? _s(fpsData?['source']),
      fps: fps ?? _d(fpsData?['averageFps']),
      fivePercentLowFps: fivePercentLowFps ?? _d(fpsData?['fivePercentLowFps']),
      onePercentLowFps: onePercentLowFps ?? _d(fpsData?['onePercentLowFps']),
      pointOnePercentLowFps:
          pointOnePercentLowFps ?? _d(fpsData?['pointOnePercentLowFps']),
      medianFps: medianFps ?? _d(fpsData?['medianFps']),
      minimumInstantFps: minimumInstantFps ?? _d(fpsData?['minimumInstantFps']),
      maximumInstantFps: maximumInstantFps ?? _d(fpsData?['maximumInstantFps']),
      frameTimeMs: frameTimeMs ?? _d(fpsData?['frameTimeMs']),
      frameTimeP95Ms: frameTimeP95Ms ?? _d(fpsData?['frameTimeP95Ms']),
      frameTimeP99Ms: frameTimeP99Ms ?? _d(fpsData?['frameTimeP99Ms']),
      bestFrameTimeMs: bestFrameTimeMs ?? _d(fpsData?['bestFrameTimeMs']),
      worstFrameTimeMs: worstFrameTimeMs ?? _d(fpsData?['worstFrameTimeMs']),
      frameStabilityScore:
          frameStabilityScore ?? _d(fpsData?['frameStabilityScore']),
      framePacingScore: framePacingScore ?? _d(fpsData?['framePacingScore']),
      performanceStabilityScore: performanceStabilityScore,
      stutter25msCount: stutter25msCount ?? _i(fpsData?['stutter25msCount']),
      stutter50msCount: stutter50msCount ?? _i(fpsData?['stutter50msCount']),
      stutter100msCount:
          stutter100msCount ?? _i(fpsData?['stutter100msCount']),
      microStutterCount: microStutterCount ?? _i(fpsData?['microStutterCount']),
      slowFrameCount: slowFrameCount ?? _i(fpsData?['slowFrameCount']),
      frozenFrameCount: frozenFrameCount ?? _i(fpsData?['frozenFrameCount']),
      estimatedDroppedFrames:
          estimatedDroppedFrames ?? _i(fpsData?['estimatedDroppedFrames']),
      missedVsyncCount: missedVsyncCount,
      refreshRateMismatch: refreshRateMismatch,
      fpsRefreshRatio: fpsRefreshRatio,
      totalFrames: totalFrames ?? _i(fpsData?['totalFrames']),
      frameWindowFrames: frameWindowFrames ?? _i(fpsData?['frameWindowFrames']),
      frameHistogramMs: frameHistogramMs,
      cpuUsage: cpuUsage,
      cpuFrequencyMhz: cpuFrequencyMhz,
      cpuFrequencyMinMhz: cpuFrequencyMinMhz,
      cpuFrequencyMaxMhz: cpuFrequencyMaxMhz,
      cpuPolicyMinMhz: cpuPolicyMinMhz,
      cpuPolicyMaxMhz: cpuPolicyMaxMhz,
      cpuPolicyAverageMaxMhz: cpuPolicyAverageMaxMhz,
      cpuCoreFrequenciesMhz: cpuCoreFrequenciesMhz,
      cpuCoreUsagePercent: cpuCoreUsagePercent,
      cpuGovernor: cpuGovernor,
      cpuClusterSummary: cpuClusterSummary,
      cpuThrottlePercent: cpuThrottlePercent,
      cpuThrottled: cpuThrottled,
      appPid: appPid,
      appCpuUsage: appCpuUsage,
      appRamMb: appRamMb,
      appRssMb: appRssMb,
      appNativeHeapMb: appNativeHeapMb,
      appGraphicsMb: appGraphicsMb,
      appThreadCount: appThreadCount,
      appNice: appNice,
      appCpuset: appCpuset,
      appUclampMin: appUclampMin,
      appUclampMax: appUclampMax,
      appCpuAffinity: appCpuAffinity,
      appSchedulerPolicy: appSchedulerPolicy,
      graphicsApi: graphicsApi,
      gameModeInfo: gameModeInfo,
      socTemperatureC: socTemperatureC,
      cpuTemperatureC: cpuTemperatureC,
      gpuTemperatureC: gpuTemperatureC,
      thermalThrottling: thermalThrottling,
      thermalStabilityScore: thermalStabilityScore,
      thermalZonesRaw: thermalZonesRaw,
      gpuModel: gpuModel ?? _s(gpuData?['model']),
      gpuVendor: gpuVendor ?? _gpuVendor(gpuModel ?? _s(gpuData?['model'])),
      gpuSource: gpuSource,
      gpuFrequencyMhz: gpuFrequencyMhz ?? _d(gpuData?['frequencyMhz']),
      gpuFrequencyMinMhz:
          gpuFrequencyMinMhz ?? _d(gpuData?['minFrequencyMhz']),
      gpuFrequencyMaxMhz:
          gpuFrequencyMaxMhz ?? _d(gpuData?['maxFrequencyMhz']),
      gpuGovernor: gpuGovernor ?? _s(gpuData?['governor']),
      gpuLoad: gpuLoad ?? _d(gpuData?['loadPercent']),
      gpuThrottlePercent: gpuThrottlePercent,
      gpuThrottled: gpuThrottled,
      ramUsedMb: ramUsedMb,
      ramTotalMb: ramTotalMb,
      ramAvailableMb: ramAvailableMb,
      swapUsedMb: swapUsedMb,
      swapTotalMb: swapTotalMb,
      zramUsedMb: zramUsedMb,
      memoryPressureAvg10: memoryPressureAvg10,
      batteryLevel: batteryLevel,
      batteryTemperatureC: batteryTemperatureC,
      batteryPowerW: batteryPowerW,
      batteryPowerSource: batteryPowerSource,
      batteryCharging: batteryCharging,
      batteryCurrentMa: batteryCurrentMa,
      batteryVoltageV: batteryVoltageV,
      batteryChargeCounterMah: batteryChargeCounterMah,
      batteryDrainPercentPerHour: batteryDrainPercentPerHour,
      batteryDrainMahPerHour: batteryDrainMahPerHour,
      estimatedGamingMinutes: estimatedGamingMinutes,
      fpsPerWatt: fpsPerWatt,
      thermalStatus: thermalStatus,
      refreshRateHz: refreshRateHz,
      networkType: networkType,
      rxKbps: rxKbps,
      txKbps: txKbps,
      networkPingMs: networkPingMs,
      networkJitterMs: networkJitterMs,
      networkPacketLossPercent: networkPacketLossPercent,
      networkProbeTarget: networkProbeTarget,
      wifiRssiDbm: wifiRssiDbm,
      wifiLinkSpeedMbps: wifiLinkSpeedMbps,
      wifiFrequencyMhz: wifiFrequencyMhz,
      wifiStandard: wifiStandard,
      cellularNetworkType: cellularNetworkType,
      cellularSignalSummary: cellularSignalSummary,
      windowWidthPx: windowWidthPx,
      windowHeightPx: windowHeightPx,
      storageUsedGb: storageUsedGb,
      storageTotalGb: storageTotalGb,
      collectorLatencyMs: collectorLatencyMs,
      monitorCpuUsage: monitorCpuUsage,
      monitorRamMb: monitorRamMb,
      surfaceFlingerRaw: surfaceFlingerRaw,
      gpuRaw: gpuRaw,
      collectorWarnings: collectorWarnings,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'sampleIntervalMs': sampleIntervalMs,
        'foregroundPackage': foregroundPackage,
        'foregroundIsGame': foregroundIsGame,
        'eventType': eventType,
        'eventLabel': eventLabel,
        'accessModeRequested': accessModeRequested,
        'accessMode': accessModeUsed,
        'backendOperational': backendOperational,
        'backendError': backendError,
        'fpsSource': fpsSource,
        'fps': fps,
        'fivePercentLowFps': fivePercentLowFps,
        'onePercentLowFps': onePercentLowFps,
        'pointOnePercentLowFps': pointOnePercentLowFps,
        'medianFps': medianFps,
        'minimumInstantFps': minimumInstantFps,
        'maximumInstantFps': maximumInstantFps,
        'frameTimeMs': frameTimeMs,
        'frameTimeP95Ms': frameTimeP95Ms,
        'frameTimeP99Ms': frameTimeP99Ms,
        'bestFrameTimeMs': bestFrameTimeMs,
        'worstFrameTimeMs': worstFrameTimeMs,
        'frameStabilityScore': frameStabilityScore,
        'framePacingScore': framePacingScore,
        'performanceStabilityScore': performanceStabilityScore,
        'stutter25msCount': stutter25msCount,
        'stutter50msCount': stutter50msCount,
        'stutter100msCount': stutter100msCount,
        'microStutterCount': microStutterCount,
        'slowFrameCount': slowFrameCount,
        'frozenFrameCount': frozenFrameCount,
        'estimatedDroppedFrames': estimatedDroppedFrames,
        'missedVsyncCount': missedVsyncCount,
        'refreshRateMismatch': refreshRateMismatch,
        'fpsRefreshRatio': fpsRefreshRatio,
        'totalFrames': totalFrames,
        'frameWindowFrames': frameWindowFrames,
        'cpuUsage': cpuUsage,
        'cpuFrequencyMhz': cpuFrequencyMhz,
        'cpuFrequencyMinMhz': cpuFrequencyMinMhz,
        'cpuFrequencyMaxMhz': cpuFrequencyMaxMhz,
        'cpuPolicyMinMhz': cpuPolicyMinMhz,
        'cpuPolicyMaxMhz': cpuPolicyMaxMhz,
        'cpuPolicyAverageMaxMhz': cpuPolicyAverageMaxMhz,
        'cpuCoreFrequenciesMhz': cpuCoreFrequenciesMhz.join('|'),
        'cpuCoreUsagePercent': cpuCoreUsagePercent.join('|'),
        'cpuGovernor': cpuGovernor,
        'cpuClusterSummary': cpuClusterSummary,
        'cpuThrottlePercent': cpuThrottlePercent,
        'cpuThrottled': cpuThrottled,
        'appPid': appPid,
        'appCpuUsage': appCpuUsage,
        'appRamMb': appRamMb,
        'appRssMb': appRssMb,
        'appNativeHeapMb': appNativeHeapMb,
        'appGraphicsMb': appGraphicsMb,
        'appThreadCount': appThreadCount,
        'appNice': appNice,
        'appCpuset': appCpuset,
        'appUclampMin': appUclampMin,
        'appUclampMax': appUclampMax,
        'appCpuAffinity': appCpuAffinity,
        'appSchedulerPolicy': appSchedulerPolicy,
        'graphicsApi': graphicsApi,
        'gameModeInfo': gameModeInfo,
        'socTemperatureC': socTemperatureC,
        'cpuTemperatureC': cpuTemperatureC,
        'gpuTemperatureC': gpuTemperatureC,
        'thermalThrottling': thermalThrottling,
        'thermalStabilityScore': thermalStabilityScore,
        'thermalZonesRaw': thermalZonesRaw,
        'gpuModel': gpuModel,
        'gpuVendor': gpuVendor,
        'gpuSource': gpuSource,
        'gpuFrequencyMhz': gpuFrequencyMhz,
        'gpuFrequencyMinMhz': gpuFrequencyMinMhz,
        'gpuFrequencyMaxMhz': gpuFrequencyMaxMhz,
        'gpuGovernor': gpuGovernor,
        'gpuLoad': gpuLoad,
        'gpuThrottlePercent': gpuThrottlePercent,
        'gpuThrottled': gpuThrottled,
        'ramUsedMb': ramUsedMb,
        'ramTotalMb': ramTotalMb,
        'ramAvailableMb': ramAvailableMb,
        'swapUsedMb': swapUsedMb,
        'swapTotalMb': swapTotalMb,
        'zramUsedMb': zramUsedMb,
        'memoryPressureAvg10': memoryPressureAvg10,
        'batteryLevel': batteryLevel,
        'batteryTemperatureC': batteryTemperatureC,
        'batteryPowerW': batteryPowerW,
        'batteryPowerSource': batteryPowerSource,
        'batteryCharging': batteryCharging,
        'batteryCurrentMa': batteryCurrentMa,
        'batteryVoltageV': batteryVoltageV,
        'batteryChargeCounterMah': batteryChargeCounterMah,
        'batteryDrainPercentPerHour': batteryDrainPercentPerHour,
        'batteryDrainMahPerHour': batteryDrainMahPerHour,
        'estimatedGamingMinutes': estimatedGamingMinutes,
        'fpsPerWatt': fpsPerWatt,
        'thermalStatus': thermalStatus,
        'refreshRateHz': refreshRateHz,
        'networkType': networkType,
        'rxKbps': rxKbps,
        'txKbps': txKbps,
        'networkPingMs': networkPingMs,
        'networkJitterMs': networkJitterMs,
        'networkPacketLossPercent': networkPacketLossPercent,
        'networkProbeTarget': networkProbeTarget,
        'wifiRssiDbm': wifiRssiDbm,
        'wifiLinkSpeedMbps': wifiLinkSpeedMbps,
        'wifiFrequencyMhz': wifiFrequencyMhz,
        'wifiStandard': wifiStandard,
        'cellularNetworkType': cellularNetworkType,
        'cellularSignalSummary': cellularSignalSummary,
        'windowWidthPx': windowWidthPx,
        'windowHeightPx': windowHeightPx,
        'storageUsedGb': storageUsedGb,
        'storageTotalGb': storageTotalGb,
        'collectorLatencyMs': collectorLatencyMs,
        'monitorCpuUsage': monitorCpuUsage,
        'monitorRamMb': monitorRamMb,
      };

  String toJsonString() => jsonEncode(toJson());
}
