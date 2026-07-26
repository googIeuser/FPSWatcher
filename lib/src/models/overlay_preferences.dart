import 'package:flutter/material.dart';

class OverlayPreferences {
  const OverlayPreferences({
    this.textSizeSp = 13,
    this.opacity = 0.92,
    this.paddingDp = 10,
    this.refreshIntervalMs = 100,
    this.textColorValue = 0xFFFFFFFF,
    this.showFps = true,
    this.showLows = true,
    this.showFrameTime = true,
    this.showSystemCpu = true,
    this.showAppCpu = true,
    this.showCpuFrequency = true,
    this.showGpuLoad = true,
    this.showGpuFrequency = true,
    this.showGameRam = true,
    this.showPower = true,
    this.showBatteryTemperature = true,
    this.showSocTemperature = false,
    this.showOnlyWhenGameDetected = true,
  });

  final double textSizeSp;
  final double opacity;
  final int paddingDp;
  final int refreshIntervalMs;
  final int textColorValue;
  final bool showFps;
  final bool showLows;
  final bool showFrameTime;
  final bool showSystemCpu;
  final bool showAppCpu;
  final bool showCpuFrequency;
  final bool showGpuLoad;
  final bool showGpuFrequency;
  final bool showGameRam;
  final bool showPower;
  final bool showBatteryTemperature;
  final bool showSocTemperature;
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

    return OverlayPreferences(
      textSizeSp: number('textSizeSp', 13).clamp(10, 24).toDouble(),
      opacity: number('opacity', 0.92).clamp(0.15, 1).toDouble(),
      paddingDp: integer('paddingDp', 10).clamp(0, 24).toInt(),
      refreshIntervalMs: _allowedRefreshInterval(
        integer('refreshIntervalMs', 100),
      ),
      textColorValue: _allowedTextColor(
        integer('textColorValue', 0xFFFFFFFF),
      ),
      showFps: flag('showFps', true),
      showLows: flag('showLows', true),
      showFrameTime: flag('showFrameTime', true),
      showSystemCpu: flag('showSystemCpu', true),
      showAppCpu: flag('showAppCpu', true),
      showCpuFrequency: flag('showCpuFrequency', true),
      showGpuLoad: flag('showGpuLoad', true),
      showGpuFrequency: flag('showGpuFrequency', true),
      showGameRam: flag('showGameRam', true),
      showPower: flag('showPower', true),
      showBatteryTemperature: flag('showBatteryTemperature', true),
      showSocTemperature: flag('showSocTemperature', false),
      showOnlyWhenGameDetected: flag('showOnlyWhenGameDetected', true),
    );
  }

  Map<String, dynamic> toMap() => {
        'textSizeSp': textSizeSp,
        'opacity': opacity,
        'paddingDp': paddingDp,
        'refreshIntervalMs': refreshIntervalMs,
        'textColorValue': textColorValue,
        'showFps': showFps,
        'showLows': showLows,
        'showFrameTime': showFrameTime,
        'showSystemCpu': showSystemCpu,
        'showAppCpu': showAppCpu,
        'showCpuFrequency': showCpuFrequency,
        'showGpuLoad': showGpuLoad,
        'showGpuFrequency': showGpuFrequency,
        'showGameRam': showGameRam,
        'showPower': showPower,
        'showBatteryTemperature': showBatteryTemperature,
        'showSocTemperature': showSocTemperature,
        'showOnlyWhenGameDetected': showOnlyWhenGameDetected,
      };

  OverlayPreferences copyWith({
    double? textSizeSp,
    double? opacity,
    int? paddingDp,
    int? refreshIntervalMs,
    int? textColorValue,
    bool? showFps,
    bool? showLows,
    bool? showFrameTime,
    bool? showSystemCpu,
    bool? showAppCpu,
    bool? showCpuFrequency,
    bool? showGpuLoad,
    bool? showGpuFrequency,
    bool? showGameRam,
    bool? showPower,
    bool? showBatteryTemperature,
    bool? showSocTemperature,
    bool? showOnlyWhenGameDetected,
  }) {
    return OverlayPreferences(
      textSizeSp: textSizeSp ?? this.textSizeSp,
      opacity: opacity ?? this.opacity,
      paddingDp: paddingDp ?? this.paddingDp,
      refreshIntervalMs: refreshIntervalMs ?? this.refreshIntervalMs,
      textColorValue: textColorValue ?? this.textColorValue,
      showFps: showFps ?? this.showFps,
      showLows: showLows ?? this.showLows,
      showFrameTime: showFrameTime ?? this.showFrameTime,
      showSystemCpu: showSystemCpu ?? this.showSystemCpu,
      showAppCpu: showAppCpu ?? this.showAppCpu,
      showCpuFrequency: showCpuFrequency ?? this.showCpuFrequency,
      showGpuLoad: showGpuLoad ?? this.showGpuLoad,
      showGpuFrequency: showGpuFrequency ?? this.showGpuFrequency,
      showGameRam: showGameRam ?? this.showGameRam,
      showPower: showPower ?? this.showPower,
      showBatteryTemperature:
          showBatteryTemperature ?? this.showBatteryTemperature,
      showSocTemperature: showSocTemperature ?? this.showSocTemperature,
      showOnlyWhenGameDetected:
          showOnlyWhenGameDetected ?? this.showOnlyWhenGameDetected,
    );
  }

  static int _allowedRefreshInterval(int value) {
    const allowed = <int>[100, 200, 500];
    return allowed.reduce(
      (best, candidate) =>
          (candidate - value).abs() < (best - value).abs() ? candidate : best,
    );
  }

  static int _allowedTextColor(int value) {
    const allowed = <int>[
      0xFFFFFFFF,
      0xFF39E7D0,
      0xFF7CFF84,
      0xFFFFD65A,
    ];
    return allowed.contains(value) ? value : 0xFFFFFFFF;
  }
}
