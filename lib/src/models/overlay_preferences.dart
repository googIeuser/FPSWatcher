import 'package:flutter/material.dart';

class OverlayPreferences {
  const OverlayPreferences({
    this.textSizeSp = 13,
    this.opacity = 0.92,
    this.paddingDp = 10,
    this.refreshIntervalMs = 100,
    this.textColorValue = 0xFFFFFFFF,
    this.layoutMode = 'vertical',
    this.adaptiveColors = true,
    this.showFps = true,
    this.showFivePercentLow = false,
    this.showLows = true,
    this.showFrameTime = true,
    this.showStability = true,
    this.showDroppedFrames = false,
    this.showSystemCpu = true,
    this.showAppCpu = true,
    this.showCpuFrequency = true,
    this.showCpuCores = false,
    this.showCpuThrottle = true,
    this.showGpuLoad = true,
    this.showGpuFrequency = true,
    this.showGpuThrottle = true,
    this.showGameRam = true,
    this.showMemory = false,
    this.showProcessDetails = false,
    this.showPower = true,
    this.showEfficiency = false,
    this.showBatteryDrain = false,
    this.showBatteryTemperature = true,
    this.showSocTemperature = false,
    this.showThermalStatus = true,
    this.showNetwork = false,
    this.showWifi = false,
    this.showMonitorOverhead = false,
    this.showOnlyWhenGameDetected = true,
  });

  final double textSizeSp;
  final double opacity;
  final int paddingDp;
  final int refreshIntervalMs;
  final int textColorValue;
  final String layoutMode;
  final bool adaptiveColors;
  final bool showFps;
  final bool showFivePercentLow;
  final bool showLows;
  final bool showFrameTime;
  final bool showStability;
  final bool showDroppedFrames;
  final bool showSystemCpu;
  final bool showAppCpu;
  final bool showCpuFrequency;
  final bool showCpuCores;
  final bool showCpuThrottle;
  final bool showGpuLoad;
  final bool showGpuFrequency;
  final bool showGpuThrottle;
  final bool showGameRam;
  final bool showMemory;
  final bool showProcessDetails;
  final bool showPower;
  final bool showEfficiency;
  final bool showBatteryDrain;
  final bool showBatteryTemperature;
  final bool showSocTemperature;
  final bool showThermalStatus;
  final bool showNetwork;
  final bool showWifi;
  final bool showMonitorOverhead;
  final bool showOnlyWhenGameDetected;

  Color get textColor => Color(textColorValue);

  factory OverlayPreferences.fromMap(Map<dynamic, dynamic> map) {
    double number(String key, double fallback) {
      final value = map[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
    }

    int integer(String key, int fallback) {
      final value = map[key];
      return value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
    }

    bool flag(String key, bool fallback) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return switch ('$value'.trim().toLowerCase()) {
        'true' || '1' || 'yes' => true,
        'false' || '0' || 'no' => false,
        _ => fallback,
      };
    }

    final layout = '${map['layoutMode'] ?? 'vertical'}'.toLowerCase();
    return OverlayPreferences(
      textSizeSp: number('textSizeSp', 13).clamp(10, 24).toDouble(),
      opacity: number('opacity', 0.92).clamp(0.15, 1).toDouble(),
      paddingDp: integer('paddingDp', 10).clamp(0, 24).toInt(),
      refreshIntervalMs: _allowedRefreshInterval(integer('refreshIntervalMs', 100)),
      textColorValue: _allowedTextColor(integer('textColorValue', 0xFFFFFFFF)),
      layoutMode: layout == 'horizontal' ? 'horizontal' : 'vertical',
      adaptiveColors: flag('adaptiveColors', true),
      showFps: flag('showFps', true),
      showFivePercentLow: flag('showFivePercentLow', false),
      showLows: flag('showLows', true),
      showFrameTime: flag('showFrameTime', true),
      showStability: flag('showStability', true),
      showDroppedFrames: flag('showDroppedFrames', false),
      showSystemCpu: flag('showSystemCpu', true),
      showAppCpu: flag('showAppCpu', true),
      showCpuFrequency: flag('showCpuFrequency', true),
      showCpuCores: flag('showCpuCores', false),
      showCpuThrottle: flag('showCpuThrottle', true),
      showGpuLoad: flag('showGpuLoad', true),
      showGpuFrequency: flag('showGpuFrequency', true),
      showGpuThrottle: flag('showGpuThrottle', true),
      showGameRam: flag('showGameRam', true),
      showMemory: flag('showMemory', false),
      showProcessDetails: flag('showProcessDetails', false),
      showPower: flag('showPower', true),
      showEfficiency: flag('showEfficiency', false),
      showBatteryDrain: flag('showBatteryDrain', false),
      showBatteryTemperature: flag('showBatteryTemperature', true),
      showSocTemperature: flag('showSocTemperature', false),
      showThermalStatus: flag('showThermalStatus', true),
      showNetwork: flag('showNetwork', false),
      showWifi: flag('showWifi', false),
      showMonitorOverhead: flag('showMonitorOverhead', false),
      showOnlyWhenGameDetected: flag('showOnlyWhenGameDetected', true),
    );
  }

  Map<String, dynamic> toMap() => {
        'textSizeSp': textSizeSp,
        'opacity': opacity,
        'paddingDp': paddingDp,
        'refreshIntervalMs': refreshIntervalMs,
        'textColorValue': textColorValue,
        'layoutMode': layoutMode,
        'adaptiveColors': adaptiveColors,
        'showFps': showFps,
        'showFivePercentLow': showFivePercentLow,
        'showLows': showLows,
        'showFrameTime': showFrameTime,
        'showStability': showStability,
        'showDroppedFrames': showDroppedFrames,
        'showSystemCpu': showSystemCpu,
        'showAppCpu': showAppCpu,
        'showCpuFrequency': showCpuFrequency,
        'showCpuCores': showCpuCores,
        'showCpuThrottle': showCpuThrottle,
        'showGpuLoad': showGpuLoad,
        'showGpuFrequency': showGpuFrequency,
        'showGpuThrottle': showGpuThrottle,
        'showGameRam': showGameRam,
        'showMemory': showMemory,
        'showProcessDetails': showProcessDetails,
        'showPower': showPower,
        'showEfficiency': showEfficiency,
        'showBatteryDrain': showBatteryDrain,
        'showBatteryTemperature': showBatteryTemperature,
        'showSocTemperature': showSocTemperature,
        'showThermalStatus': showThermalStatus,
        'showNetwork': showNetwork,
        'showWifi': showWifi,
        'showMonitorOverhead': showMonitorOverhead,
        'showOnlyWhenGameDetected': showOnlyWhenGameDetected,
      };

  OverlayPreferences copyWith({
    double? textSizeSp,
    double? opacity,
    int? paddingDp,
    int? refreshIntervalMs,
    int? textColorValue,
    String? layoutMode,
    bool? adaptiveColors,
    bool? showFps,
    bool? showFivePercentLow,
    bool? showLows,
    bool? showFrameTime,
    bool? showStability,
    bool? showDroppedFrames,
    bool? showSystemCpu,
    bool? showAppCpu,
    bool? showCpuFrequency,
    bool? showCpuCores,
    bool? showCpuThrottle,
    bool? showGpuLoad,
    bool? showGpuFrequency,
    bool? showGpuThrottle,
    bool? showGameRam,
    bool? showMemory,
    bool? showProcessDetails,
    bool? showPower,
    bool? showEfficiency,
    bool? showBatteryDrain,
    bool? showBatteryTemperature,
    bool? showSocTemperature,
    bool? showThermalStatus,
    bool? showNetwork,
    bool? showWifi,
    bool? showMonitorOverhead,
    bool? showOnlyWhenGameDetected,
  }) => OverlayPreferences(
        textSizeSp: textSizeSp ?? this.textSizeSp,
        opacity: opacity ?? this.opacity,
        paddingDp: paddingDp ?? this.paddingDp,
        refreshIntervalMs: refreshIntervalMs ?? this.refreshIntervalMs,
        textColorValue: textColorValue ?? this.textColorValue,
        layoutMode: layoutMode ?? this.layoutMode,
        adaptiveColors: adaptiveColors ?? this.adaptiveColors,
        showFps: showFps ?? this.showFps,
        showFivePercentLow: showFivePercentLow ?? this.showFivePercentLow,
        showLows: showLows ?? this.showLows,
        showFrameTime: showFrameTime ?? this.showFrameTime,
        showStability: showStability ?? this.showStability,
        showDroppedFrames: showDroppedFrames ?? this.showDroppedFrames,
        showSystemCpu: showSystemCpu ?? this.showSystemCpu,
        showAppCpu: showAppCpu ?? this.showAppCpu,
        showCpuFrequency: showCpuFrequency ?? this.showCpuFrequency,
        showCpuCores: showCpuCores ?? this.showCpuCores,
        showCpuThrottle: showCpuThrottle ?? this.showCpuThrottle,
        showGpuLoad: showGpuLoad ?? this.showGpuLoad,
        showGpuFrequency: showGpuFrequency ?? this.showGpuFrequency,
        showGpuThrottle: showGpuThrottle ?? this.showGpuThrottle,
        showGameRam: showGameRam ?? this.showGameRam,
        showMemory: showMemory ?? this.showMemory,
        showProcessDetails: showProcessDetails ?? this.showProcessDetails,
        showPower: showPower ?? this.showPower,
        showEfficiency: showEfficiency ?? this.showEfficiency,
        showBatteryDrain: showBatteryDrain ?? this.showBatteryDrain,
        showBatteryTemperature: showBatteryTemperature ?? this.showBatteryTemperature,
        showSocTemperature: showSocTemperature ?? this.showSocTemperature,
        showThermalStatus: showThermalStatus ?? this.showThermalStatus,
        showNetwork: showNetwork ?? this.showNetwork,
        showWifi: showWifi ?? this.showWifi,
        showMonitorOverhead: showMonitorOverhead ?? this.showMonitorOverhead,
        showOnlyWhenGameDetected: showOnlyWhenGameDetected ?? this.showOnlyWhenGameDetected,
      );

  OverlayPreferences preset(String name) => switch (name) {
        'minimal' => copyWith(
            showFps: true,
            showFivePercentLow: false,
            showLows: false,
            showFrameTime: false,
            showStability: false,
            showDroppedFrames: false,
            showSystemCpu: false,
            showAppCpu: false,
            showCpuFrequency: false,
            showCpuCores: false,
            showCpuThrottle: false,
            showGpuLoad: false,
            showGpuFrequency: false,
            showGpuThrottle: false,
            showGameRam: false,
            showMemory: false,
            showProcessDetails: false,
            showPower: false,
            showEfficiency: false,
            showBatteryDrain: false,
            showBatteryTemperature: false,
            showSocTemperature: false,
            showThermalStatus: false,
            showNetwork: false,
            showWifi: false,
            showMonitorOverhead: false,
          ),
        'performance' => copyWith(
            showFps: true,
            showFivePercentLow: true,
            showLows: true,
            showFrameTime: true,
            showStability: true,
            showDroppedFrames: true,
            showSystemCpu: true,
            showAppCpu: true,
            showCpuFrequency: true,
            showCpuThrottle: true,
            showGpuLoad: true,
            showGpuFrequency: true,
            showGpuThrottle: true,
            showGameRam: true,
            showPower: false,
            showThermalStatus: false,
            showNetwork: false,
            showWifi: false,
          ),
        'battery' => copyWith(
            showFps: true,
            showFivePercentLow: false,
            showLows: false,
            showFrameTime: false,
            showStability: false,
            showDroppedFrames: false,
            showSystemCpu: false,
            showAppCpu: false,
            showCpuFrequency: false,
            showCpuThrottle: false,
            showGpuLoad: false,
            showGpuFrequency: false,
            showGpuThrottle: false,
            showGameRam: false,
            showPower: true,
            showEfficiency: true,
            showBatteryDrain: true,
            showBatteryTemperature: true,
            showSocTemperature: true,
            showThermalStatus: true,
            showNetwork: false,
            showWifi: false,
          ),
        'thermal' => copyWith(
            showFps: true,
            showFrameTime: true,
            showCpuFrequency: true,
            showCpuThrottle: true,
            showGpuFrequency: true,
            showGpuThrottle: true,
            showPower: true,
            showBatteryTemperature: true,
            showSocTemperature: true,
            showThermalStatus: true,
          ),
        'network' => copyWith(showFps: true, showNetwork: true, showWifi: true),
        'full' => copyWith(
            showFps: true,
            showFivePercentLow: true,
            showLows: true,
            showFrameTime: true,
            showStability: true,
            showDroppedFrames: true,
            showSystemCpu: true,
            showAppCpu: true,
            showCpuFrequency: true,
            showCpuCores: true,
            showCpuThrottle: true,
            showGpuLoad: true,
            showGpuFrequency: true,
            showGpuThrottle: true,
            showGameRam: true,
            showMemory: true,
            showProcessDetails: true,
            showPower: true,
            showEfficiency: true,
            showBatteryDrain: true,
            showBatteryTemperature: true,
            showSocTemperature: true,
            showThermalStatus: true,
            showNetwork: true,
            showWifi: true,
            showMonitorOverhead: true,
          ),
        _ => this,
      };

  static int _allowedRefreshInterval(int value) {
    const allowed = <int>[100, 200, 500];
    return allowed.reduce(
      (best, candidate) =>
          (candidate - value).abs() < (best - value).abs() ? candidate : best,
    );
  }

  static int _allowedTextColor(int value) {
    const allowed = <int>[0xFFFFFFFF, 0xFF39E7D0, 0xFF7CFF84, 0xFFFFD65A];
    return allowed.contains(value) ? value : 0xFFFFFFFF;
  }
}
