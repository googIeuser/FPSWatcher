import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/telemetry_sample.dart';
import '../state/app_controller.dart';
import 'widgets/metric_card.dart';
import 'widgets/sparkline.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey _captureKey = GlobalKey();
  bool _exporting = false;
  AppController get controller => widget.controller;

  String n(num? value, [int digits = 0]) => value == null ? '—' : value.toStringAsFixed(digits);

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await controller.exportPng(bytes.buffer.asUint8List());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PNG export completed.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.latest;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 980 ? 4 : width >= 680 ? 3 : 2;
    final fpsHistory = List<double>.unmodifiable(controller.fpsHistory);
    return RepaintBoundary(
      key: _captureKey,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshStatus();
            await controller.collectNow();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _Header(controller: controller),
              const SizedBox(height: 14),
              _BackendBar(controller: controller),
              if (s != null && !s.backendOperational) ...[
                const SizedBox(height: 10),
                _Warning(text: s.backendError ?? 'The selected privileged backend is unavailable.'),
              ],
              const SizedBox(height: 14),
              _FpsHero(sample: s, history: fpsHistory),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.overlayPermission ? controller.toggleOverlay : controller.requestOverlayPermission,
                      icon: Icon(controller.overlayRunning ? Icons.layers_clear_outlined : Icons.picture_in_picture_alt_outlined),
                      label: Text(controller.overlayRunning ? 'Stop overlay' : 'Start overlay'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportPng,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Save PNG'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Title('PERFORMANCE'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: '5% low', value: '${n(s?.fivePercentLowFps, 1)} FPS', subtitle: 'rolling low tail', icon: Icons.speed_outlined),
                MetricCard(title: '1% low', value: '${n(s?.onePercentLowFps, 1)} FPS', subtitle: 'requires ≥100 frames', icon: Icons.trending_down),
                MetricCard(title: '0.1% low', value: '${n(s?.pointOnePercentLowFps, 1)} FPS', subtitle: 'requires ≥1,000 frames', icon: Icons.ssid_chart),
                MetricCard(title: 'Frame stability', value: '${n(s?.frameStabilityScore, 1)}%', subtitle: 'mean / P99 frame time', icon: Icons.monitor_heart_outlined, progress: s?.frameStabilityScore == null ? null : s!.frameStabilityScore! / 100),
                MetricCard(title: 'Frame pacing', value: '${n(s?.framePacingScore, 1)}%', subtitle: 'frame-time variance score', icon: Icons.multiline_chart_outlined, progress: s?.framePacingScore == null ? null : s!.framePacingScore! / 100),
                MetricCard(title: 'Performance stability', value: '${n(s?.performanceStabilityScore, 1)}%', subtitle: 'frame + pacing + thermal health', icon: Icons.health_and_safety, progress: s?.performanceStabilityScore == null ? null : s!.performanceStabilityScore! / 100),
                MetricCard(title: 'P99 frame time', value: '${n(s?.frameTimeP99Ms, 2)} ms', subtitle: 'P95 ${n(s?.frameTimeP95Ms, 2)} ms', icon: Icons.timeline),
                MetricCard(title: 'Worst frame', value: '${n(s?.worstFrameTimeMs, 2)} ms', subtitle: 'best ${n(s?.bestFrameTimeMs, 2)} ms', icon: Icons.warning_amber_outlined),
                MetricCard(title: 'Stutters', value: '${s?.stutter25msCount ?? '—'}', subtitle: '>50 ms ${s?.stutter50msCount ?? '—'} · >100 ms ${s?.stutter100msCount ?? '—'}', icon: Icons.bolt_outlined),
                MetricCard(title: 'Dropped frames', value: '${s?.estimatedDroppedFrames ?? '—'}', subtitle: s?.refreshRateMismatch == true ? 'refresh mismatch detected' : 'estimated missed VSyncs', icon: Icons.layers_outlined),
                MetricCard(title: 'Micro-stutters', value: '${s?.microStutterCount ?? '—'}', subtitle: '20–50 ms rolling frames', icon: Icons.flash_on_outlined),
                MetricCard(title: 'Frozen frames', value: '${s?.frozenFrameCount ?? '—'}', subtitle: '≥700 ms frames', icon: Icons.ac_unit_outlined),
                MetricCard(title: 'FPS range', value: '${n(s?.minimumInstantFps, 0)}–${n(s?.maximumInstantFps, 0)}', subtitle: 'instantaneous rolling range', icon: Icons.compare_arrows_outlined),
              ]),
              if (s?.frameHistogramMs.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _FrameHistogram(points: s!.frameHistogramMs),
              ],
              const SizedBox(height: 20),
              _Title('CPU & PROCESS'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: 'System CPU', value: '${n(s?.cpuUsage, 1)}%', subtitle: s?.cpuGovernor ?? 'governor unavailable', icon: Icons.memory_outlined, progress: s?.cpuUsage == null ? null : s!.cpuUsage! / 100),
                MetricCard(title: 'Game CPU', value: '${n(s?.appCpuUsage, 1)}%', subtitle: s?.appPid == null ? 'waiting for process' : 'PID ${s?.appPid}', icon: Icons.sports_esports_outlined),
                MetricCard(title: 'CPU clock', value: '${n(s?.cpuFrequencyMhz)} MHz', subtitle: '${n(s?.cpuPolicyMinMhz)}–${n(s?.cpuPolicyMaxMhz)} MHz policy', icon: Icons.av_timer_outlined),
                MetricCard(title: 'CPU throttle', value: s?.cpuThrottled == true ? 'THROTTLED' : '${n(s?.cpuThrottlePercent, 1)}%', subtitle: 'frequency headroom heuristic', icon: Icons.thermostat_auto_outlined),
                MetricCard(title: 'Threads', value: '${s?.appThreadCount ?? '—'}', subtitle: 'nice ${s?.appNice ?? '—'} · ${s?.appCpuset ?? 'cpuset unavailable'}', icon: Icons.account_tree_outlined),
                MetricCard(title: 'UClamp', value: '${n(s?.appUclampMin, 0)}–${n(s?.appUclampMax, 0)}', subtitle: 'scheduler utilization clamp', icon: Icons.tune_outlined),
                MetricCard(title: 'CPU affinity', value: s?.appCpuAffinity ?? 'Unavailable', subtitle: s?.appSchedulerPolicy ?? 'scheduler policy unavailable', icon: Icons.hub_outlined),
                MetricCard(title: 'CPU clusters', value: s?.cpuClusterSummary ?? 'Unavailable', subtitle: 'current / min-max MHz by policy', icon: Icons.account_tree_outlined),
                MetricCard(title: 'Graphics API', value: s?.graphicsApi ?? 'Unavailable', subtitle: s?.gameModeInfo ?? 'game mode info unavailable', icon: Icons.videogame_asset_outlined),
              ]),
              if (s?.cpuCoreUsagePercent.isNotEmpty == true || s?.cpuCoreFrequenciesMhz.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _CoreStrip(sample: s!),
              ],
              const SizedBox(height: 20),
              _Title('GPU'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: 'GPU load', value: '${n(s?.gpuLoad, 1)}%', subtitle: s?.gpuSource ?? 'restricted / unavailable', icon: Icons.developer_board_outlined, progress: s?.gpuLoad == null ? null : s!.gpuLoad! / 100),
                MetricCard(title: 'GPU clock', value: '${n(s?.gpuFrequencyMhz)} MHz', subtitle: '${n(s?.gpuFrequencyMinMhz)}–${n(s?.gpuFrequencyMaxMhz)} MHz', icon: Icons.speed_outlined),
                MetricCard(title: 'GPU governor', value: s?.gpuGovernor ?? 'Unavailable', subtitle: '${s?.gpuVendor ?? 'Unknown vendor'} · ${s?.gpuModel ?? 'renderer unavailable'}', icon: Icons.settings_input_component_outlined),
                MetricCard(title: 'GPU throttle', value: s?.gpuThrottled == true ? 'THROTTLED' : '${n(s?.gpuThrottlePercent, 1)}%', subtitle: 'load-aware frequency headroom', icon: Icons.device_thermostat_outlined),
              ]),
              const SizedBox(height: 20),
              _Title('POWER & THERMALS'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: 'Instant power', value: s?.batteryCharging == true ? 'Charging' : '${n(s?.batteryPowerW, 2)} W', subtitle: '${n(s?.batteryVoltageV, 2)} V · ${n(s?.batteryCurrentMa, 0)} mA', icon: Icons.bolt_outlined),
                MetricCard(title: 'Efficiency', value: '${n(s?.fpsPerWatt, 2)} FPS/W', subtitle: 'render efficiency', icon: Icons.energy_savings_leaf_outlined),
                MetricCard(title: 'Battery drain', value: '${n(s?.batteryDrainPercentPerHour, 2)} %/h', subtitle: '${n(s?.batteryDrainMahPerHour, 0)} mAh/h', icon: Icons.battery_5_bar_outlined),
                MetricCard(title: 'Gaming time', value: _duration(s?.estimatedGamingMinutes), subtitle: '${n(s?.batteryLevel, 0)}% battery remaining', icon: Icons.timelapse_outlined),
                MetricCard(title: 'Battery temp', value: '${n(s?.batteryTemperatureC, 1)} °C', subtitle: s?.batteryPowerSource ?? 'power source unavailable', icon: Icons.thermostat_outlined),
                MetricCard(title: 'SoC temp', value: '${n(s?.socTemperatureC, 1)} °C', subtitle: _thermal(s?.thermalStatus), icon: Icons.device_thermostat_outlined),
                MetricCard(title: 'CPU / GPU temp', value: '${n(s?.cpuTemperatureC, 1)} / ${n(s?.gpuTemperatureC, 1)} °C', subtitle: 'best matching thermal zones', icon: Icons.thermostat_auto_outlined),
                MetricCard(title: 'Thermal score', value: '${n(s?.thermalStabilityScore, 1)}%', subtitle: s?.thermalThrottling == true ? 'throttling detected' : 'no active throttle detected', icon: Icons.shield_outlined, progress: s?.thermalStabilityScore == null ? null : s!.thermalStabilityScore! / 100),
              ]),
              const SizedBox(height: 20),
              _Title('MEMORY & NETWORK'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: 'Game PSS', value: '${n(s?.appRamMb)} MB', subtitle: 'RSS ${n(s?.appRssMb)} MB', icon: Icons.storage_outlined),
                MetricCard(title: 'Native / Graphics', value: '${n(s?.appNativeHeapMb)} / ${n(s?.appGraphicsMb)} MB', subtitle: 'process memory breakdown', icon: Icons.data_usage_outlined),
                MetricCard(title: 'Swap / ZRAM', value: '${n(s?.swapUsedMb)} / ${n(s?.zramUsedMb)} MB', subtitle: 'memory PSI ${n(s?.memoryPressureAvg10, 2)}', icon: Icons.swap_vert_outlined),
                MetricCard(title: 'Network', value: s?.networkType ?? 'Unavailable', subtitle: 'RX ${n(s?.rxKbps, 0)} · TX ${n(s?.txKbps, 0)} KB/s', icon: Icons.public_outlined),
                MetricCard(title: 'Ping', value: '${n(s?.networkPingMs, 1)} ms', subtitle: 'jitter ${n(s?.networkJitterMs, 1)} · loss ${n(s?.networkPacketLossPercent, 1)}%', icon: Icons.network_ping_outlined),
                MetricCard(title: 'Wi-Fi', value: '${s?.wifiRssiDbm ?? '—'} dBm', subtitle: '${n(s?.wifiLinkSpeedMbps)} Mbps · ${s?.wifiStandard ?? 'standard unavailable'}', icon: Icons.wifi_outlined),
                MetricCard(title: 'Cellular', value: s?.cellularNetworkType ?? 'Unavailable', subtitle: s?.cellularSignalSummary ?? 'signal summary unavailable', icon: Icons.signal_cellular_alt),
                MetricCard(title: 'Game surface', value: s?.windowWidthPx == null ? 'Unavailable' : '${s?.windowWidthPx} × ${s?.windowHeightPx}', subtitle: '${s?.graphicsApi ?? 'graphics API unavailable'} · ${n(s?.refreshRateHz)} Hz', icon: Icons.aspect_ratio),
              ]),
              const SizedBox(height: 20),
              _Title('FPSWATCHER OVERHEAD'),
              const SizedBox(height: 9),
              _Grid(columns: columns, children: [
                MetricCard(title: 'Collector latency', value: '${n(s?.collectorLatencyMs, 2)} ms', subtitle: 'native sampling latency', icon: Icons.timer_outlined),
                MetricCard(title: 'Actual sample interval', value: '${s?.sampleIntervalMs ?? '—'} ms', subtitle: 'time between native snapshots', icon: Icons.update_outlined),
                MetricCard(title: 'Monitor CPU', value: '${n(s?.monitorCpuUsage, 1)}%', subtitle: 'FPSWatcher process overhead', icon: Icons.monitor_heart_outlined),
                MetricCard(title: 'Monitor RAM', value: '${n(s?.monitorRamMb, 1)} MB', subtitle: 'process PSS', icon: Icons.memory_outlined),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _duration(double? minutes) {
    if (minutes == null) return '—';
    final total = minutes.round();
    return '${total ~/ 60}h ${total % 60}m';
  }

  String _thermal(int? status) => switch (status) {
        0 => 'No thermal pressure',
        1 => 'Light thermal pressure',
        2 => 'Moderate thermal pressure',
        3 => 'Severe thermal pressure',
        4 => 'Critical thermal pressure',
        5 => 'Emergency thermal pressure',
        6 => 'Shutdown thermal pressure',
        _ => 'Thermal status unavailable',
      };
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: columns >= 4 ? 1.20 : columns == 3 ? 1.05 : 0.90,
        children: children,
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4));
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FPSWatcher', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
              Text(
                controller.latest?.foregroundPackage ?? 'Waiting for a foreground game',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
              if (controller.latest?.foregroundPackage != null)
                Text(
                  controller.latest?.foregroundIsGame == true ? 'Game category detected' : 'Foreground application',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
            ]),
          ),
          if (controller.recorder.isRecording)
            Chip(avatar: Icon(Icons.fiber_manual_record, size: 14, color: Theme.of(context).colorScheme.error), label: const Text('REC')),
        ],
      );
}

class _BackendBar extends StatelessWidget {
  const _BackendBar({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => SegmentedButton<AccessMode>(
        segments: const [
          ButtonSegment(value: AccessMode.shizuku, label: Text('Shizuku'), icon: Icon(Icons.admin_panel_settings_outlined)),
          ButtonSegment(value: AccessMode.root, label: Text('Root'), icon: Icon(Icons.security_outlined)),
        ],
        selected: {controller.accessMode},
        onSelectionChanged: (values) => controller.setAccessMode(values.first),
      );
}

class _FpsHero extends StatelessWidget {
  const _FpsHero({required this.sample, required this.history});
  final TelemetrySample? sample;
  final List<double> history;
  String v(double? value, [int digits = 1]) => value == null ? '—' : value.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('REAL-TIME FPS', style: TextStyle(color: Colors.white54, letterSpacing: 1.2)),
                  Text(v(sample?.fps), style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                ]),
                const Spacer(),
                _Mini('MEDIAN', v(sample?.medianFps)),
                const SizedBox(width: 16),
                _Mini('1% LOW', v(sample?.onePercentLowFps)),
                const SizedBox(width: 16),
                _Mini('0.1%', v(sample?.pointOnePercentLowFps)),
              ]),
              const SizedBox(height: 10),
              Sparkline(values: history.isEmpty ? const [0, 0] : history),
              const SizedBox(height: 8),
              Row(children: [
                Text('${v(sample?.frameTimeMs, 2)} ms frame · ${v(sample?.refreshRateHz, 0)} Hz display', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                Text('${sample?.frameWindowFrames ?? sample?.totalFrames ?? '—'} rolling frames', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ],
          ),
        ),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ]);
}

class _CoreStrip extends StatelessWidget {
  const _CoreStrip({required this.sample});
  final TelemetrySample sample;
  @override
  Widget build(BuildContext context) {
    final count = [sample.cpuCoreUsagePercent.length, sample.cpuCoreFrequenciesMhz.length].reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(count, (index) {
            final load = index < sample.cpuCoreUsagePercent.length ? sample.cpuCoreUsagePercent[index] : null;
            final freq = index < sample.cpuCoreFrequenciesMhz.length ? sample.cpuCoreFrequenciesMhz[index] : null;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), border: Border.all(color: Colors.white10)),
              child: Text('C$index  ${load?.toStringAsFixed(0) ?? '—'}%  ${freq?.toStringAsFixed(0) ?? '—'} MHz', style: const TextStyle(fontSize: 11)),
            );
          }),
        ),
      ),
    );
  }
}


class _FrameHistogram extends StatelessWidget {
  const _FrameHistogram({required this.points});
  final List<List<double>> points;

  @override
  Widget build(BuildContext context) {
    final compact = points.length <= 24
        ? points
        : List<List<double>>.generate(24, (index) {
            final start = (index * points.length / 24).floor();
            final end = (((index + 1) * points.length / 24).ceil()).clamp(start + 1, points.length).toInt();
            final slice = points.sublist(start, end);
            final count = slice.fold<double>(0, (sum, item) => sum + item[1]);
            final weighted = slice.fold<double>(0, (sum, item) => sum + item[0] * item[1]);
            return <double>[count <= 0 ? slice.first[0] : weighted / count, count];
          });
    final maxCount = compact.fold<double>(1, (max, item) => item[1] > max ? item[1] : max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FRAME-TIME HISTOGRAM', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: compact.map((point) {
                  final height = (point[1] / maxCount).clamp(.03, 1.0).toDouble();
                  final ms = point[0];
                  final color = ms >= 50
                      ? Theme.of(context).colorScheme.error
                      : ms >= 25
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.primary;
                  return Expanded(
                    child: Tooltip(
                      message: '${ms.toStringAsFixed(1)} ms · ${point[1].toStringAsFixed(0)} frames',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          heightFactor: height,
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .75))),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text('<25 ms', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10)),
                const Spacer(),
                Text('25–50 ms', style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 10)),
                const Spacer(),
                Text('≥50 ms', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
