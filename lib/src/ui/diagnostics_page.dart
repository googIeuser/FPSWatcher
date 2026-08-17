import 'package:flutter/material.dart';
import '../models/telemetry_sample.dart';
import '../state/app_controller.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final sample = controller.latest;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(
          'Diagnostics',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Inspect backend health, telemetry sources, sampling latency and raw capability coverage.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'BACKEND HEALTH',
          children: [
            _Row('Selected backend', controller.accessMode.label),
            _Row('Root shell', controller.rootAvailable ? 'Operational' : 'Unavailable'),
            _Row('Shizuku UserService', controller.shizukuOperational ? 'Operational' : 'Unavailable'),
            _Row('Usage access', controller.usageAccess ? 'Granted' : 'Missing'),
            _Row('Overlay permission', controller.overlayPermission ? 'Granted' : 'Missing'),
            _Row('Monitor service', controller.monitorServiceRunning ? 'Running' : 'Stopped'),
            _Row('Collector latency', _ms(sample?.collectorLatencyMs)),
            _Row('Actual sample interval', sample?.sampleIntervalMs == null ? '—' : '${sample?.sampleIntervalMs} ms'),
            _Row('FPSWatcher CPU', _percent(sample?.monitorCpuUsage)),
            _Row('FPSWatcher RAM', _mb(sample?.monitorRamMb)),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'CAPABILITY MATRIX',
          children: [
            _Capability('FPS / frame pacing', sample?.fps != null, sample?.fpsSource),
            _Capability('Frame histogram', sample?.frameHistogramMs.isNotEmpty == true, '${sample?.frameHistogramMs.length ?? 0} bins'),
            _Capability('Performance stability score', sample?.performanceStabilityScore != null, sample?.performanceStabilityScore == null ? null : '${sample?.performanceStabilityScore?.toStringAsFixed(1)}%'),
            _Capability('1% / 0.1% lows', sample?.onePercentLowFps != null || sample?.pointOnePercentLowFps != null, 'rolling frame window'),
            _Capability('Game CPU', sample?.appCpuUsage != null, sample?.appPid == null ? null : 'PID ${sample?.appPid}'),
            _Capability('Per-core CPU load', sample?.cpuCoreUsagePercent.isNotEmpty == true, '${sample?.cpuCoreUsagePercent.length ?? 0} cores'),
            _Capability('Scheduler / affinity', sample?.appCpuAffinity != null || sample?.appSchedulerPolicy != null, sample?.appSchedulerPolicy),
            _Capability('Graphics API', sample?.graphicsApi != null, sample?.graphicsApi),
            _Capability('GPU load', sample?.gpuLoad != null, sample?.gpuSource),
            _Capability('GPU frequency', sample?.gpuFrequencyMhz != null, sample?.gpuGovernor),
            _Capability('Power', sample?.batteryPowerW != null || sample?.batteryCharging == true, sample?.batteryPowerSource),
            _Capability('SoC thermals', sample?.socTemperatureC != null, sample?.thermalThrottling == true ? 'throttling detected' : null),
            _Capability('CPU / GPU thermal zones', sample?.cpuTemperatureC != null || sample?.gpuTemperatureC != null, '${sample?.cpuTemperatureC?.toStringAsFixed(1) ?? '—'} / ${sample?.gpuTemperatureC?.toStringAsFixed(1) ?? '—'} °C'),
            _Capability('Process memory', sample?.appRamMb != null, sample?.appCpuset),
            _Capability('Swap / ZRAM', sample?.swapUsedMb != null || sample?.zramUsedMb != null, null),
            _Capability('Network probe', sample?.networkPingMs != null, sample?.networkProbeTarget),
            _Capability('Wi-Fi telemetry', sample?.wifiRssiDbm != null || sample?.wifiLinkSpeedMbps != null, sample?.wifiStandard),
            _Capability('Cellular telemetry', sample?.cellularNetworkType != null || sample?.cellularSignalSummary != null, sample?.cellularNetworkType),
            _Capability('Game surface dimensions', sample?.windowWidthPx != null && sample?.windowHeightPx != null, sample?.windowWidthPx == null ? null : '${sample?.windowWidthPx} × ${sample?.windowHeightPx}'),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'LIVE SOURCES',
          children: [
            _Row('Foreground package', sample?.foregroundPackage ?? 'Unavailable'),
            _Row('Game category', sample?.foregroundIsGame == true ? 'Detected game' : sample?.foregroundIsGame == false ? 'Not categorized as game' : 'Unknown'),
            _Row('FPS source', sample?.fpsSource ?? 'Unavailable'),
            _Row('GPU source', sample?.gpuSource ?? 'Unavailable'),
            _Row('GPU renderer', sample?.gpuModel ?? 'Unavailable'),
            _Row('GPU vendor', sample?.gpuVendor ?? 'Unavailable'),
            _Row('CPU governor', sample?.cpuGovernor ?? 'Unavailable'),
            _Row('Graphics API', sample?.graphicsApi ?? 'Unavailable'),
            _Row('Game mode info', sample?.gameModeInfo ?? 'Unavailable'),
            _Row('GPU governor', sample?.gpuGovernor ?? 'Unavailable'),
            _Row('Power source', sample?.batteryPowerSource ?? (sample?.batteryCharging == true ? 'Charging' : 'Unavailable')),
            _Row('Network', sample?.networkType ?? 'Unavailable'),
            _Row('Cellular', sample?.cellularNetworkType ?? 'Unavailable'),
            _Row('Cellular signal', sample?.cellularSignalSummary ?? 'Unavailable'),
            _Row('Game surface', sample?.windowWidthPx == null ? 'Unavailable' : '${sample?.windowWidthPx} × ${sample?.windowHeightPx}'),
            _Row('CPU temperature', sample?.cpuTemperatureC == null ? 'Unavailable' : '${sample?.cpuTemperatureC?.toStringAsFixed(1)} °C'),
            _Row('GPU temperature', sample?.gpuTemperatureC == null ? 'Unavailable' : '${sample?.gpuTemperatureC?.toStringAsFixed(1)} °C'),
          ],
        ),
        const SizedBox(height: 14),
        if (sample?.collectorWarnings.isNotEmpty == true)
          _Section(
            title: 'COLLECTOR WARNINGS',
            children: sample!.collectorWarnings
                .map((warning) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text('• $warning', style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
                    ))
                .toList(growable: false),
          ),
        if (controller.lastError != null) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'LAST ERROR',
            children: [Text(controller.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          ),
        ],
        const SizedBox(height: 14),
        _Section(
          title: 'EXPERT SNAPSHOT',
          children: [
            _Code('CPU cluster summary', sample?.cpuClusterSummary ?? 'Unavailable'),
            _Code('CPU core frequencies', _list(sample?.cpuCoreFrequenciesMhz, ' MHz')),
            _Code('CPU core usage', _list(sample?.cpuCoreUsagePercent, '%')),
            _Code('CPUSet', sample?.appCpuset ?? 'Unavailable'),
            _Code('CPU affinity mask', sample?.appCpuAffinity ?? 'Unavailable'),
            _Code('Scheduler policy', sample?.appSchedulerPolicy ?? 'Unavailable'),
            _Code('UClamp', '${sample?.appUclampMin?.toStringAsFixed(1) ?? '—'} / ${sample?.appUclampMax?.toStringAsFixed(1) ?? '—'}'),
            _Code('Thermal zones', sample?.thermalZonesRaw ?? 'Unavailable'),
            _Code('SurfaceFlinger excerpt', _excerpt(sample?.surfaceFlingerRaw)),
            _Code('GPU raw excerpt', _excerpt(sample?.gpuRaw)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await controller.refreshStatus();
              await controller.collectNow();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh diagnostics'),
          ),
        ),
      ],
    );
  }

  static String _percent(double? value) => value == null ? '—' : '${value.toStringAsFixed(1)}%';
  static String _ms(double? value) => value == null ? '—' : '${value.toStringAsFixed(2)} ms';
  static String _mb(double? value) => value == null ? '—' : '${value.toStringAsFixed(1)} MB';
  static String _list(List<double>? values, String suffix) =>
      values == null || values.isEmpty ? 'Unavailable' : values.map((v) => '${v.toStringAsFixed(0)}$suffix').join(' · ');
  static String _excerpt(String? value) {
    if (value == null || value.trim().isEmpty) return 'Unavailable';
    final compact = value.trim();
    return compact.length <= 1600 ? compact : '${compact.substring(0, 1600)}\n…';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.4)),
          const SizedBox(height: 9),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(width: 12),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _Capability extends StatelessWidget {
  const _Capability(this.label, this.available, this.source);
  final String label;
  final bool available;
  final String? source;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(available ? Icons.check_circle : Icons.remove_circle_outline, size: 18, color: available ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            if (source != null) Flexible(child: Text(source!, textAlign: TextAlign.right, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
          ],
        ),
      );
}

class _Code extends StatelessWidget {
  const _Code(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      );
}
