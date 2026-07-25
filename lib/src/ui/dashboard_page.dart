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

  String _number(double? value, {int decimals = 0, String fallback = '—'}) {
    return value == null || value.isNaN ? fallback : value.toStringAsFixed(decimals);
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await controller.exportPng(bytes.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PNG export completed.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sample = controller.latest;
    final fpsHistory = controller.history
        .map((item) => item.fps)
        .whereType<double>()
        .toList(growable: false);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : width >= 620 ? 3 : 2;
    final cpuClockSubtitle = sample?.cpuFrequencyMinMhz == null
        ? '${_number(sample?.cpuFrequencyMhz)} MHz average'
        : '${_number(sample?.cpuFrequencyMinMhz)}–${_number(sample?.cpuFrequencyMaxMhz)} MHz';
    final gpuRestricted = sample?.gpuLoad == null && sample?.gpuFrequencyMhz == null;

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
              const SizedBox(height: 18),
              _ModeSelector(controller: controller),
              const SizedBox(height: 14),
              _StatusStrip(controller: controller),
              const SizedBox(height: 18),
              _FpsHero(sample: sample, history: fpsHistory),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.overlayPermission
                          ? controller.toggleOverlay
                          : controller.requestOverlayPermission,
                      icon: Icon(
                        controller.overlayRunning
                            ? Icons.layers_clear_outlined
                            : Icons.picture_in_picture_alt_outlined,
                      ),
                      label: Text(
                        controller.overlayRunning ? 'Stop overlay' : 'Start overlay',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportPng,
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: const Text('Save PNG'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'LIVE TELEMETRY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1.4,
                    ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: width >= 900 ? 1.18 : width >= 620 ? 1.02 : 0.90,
                children: [
                  MetricCard(
                    title: 'Game CPU',
                    value: sample?.appCpuUsage == null
                        ? 'Unavailable'
                        : '${_number(sample?.appCpuUsage, decimals: 1)}%',
                    subtitle: sample?.appPid == null
                        ? (sample?.foregroundPackage ?? 'Waiting for game process')
                        : 'PID ${sample?.appPid} · ${sample?.accessModeUsed ?? 'standard'}',
                    icon: Icons.sports_esports_outlined,
                  ),
                  MetricCard(
                    title: 'Game RAM',
                    value: sample?.appRamMb == null
                        ? 'Unavailable'
                        : '${_number(sample?.appRamMb)} MB',
                    subtitle: sample?.appRssMb == null
                        ? 'PSS / process memory'
                        : 'RSS ${_number(sample?.appRssMb)} MB',
                    icon: Icons.data_usage_outlined,
                  ),
                  MetricCard(
                    title: 'GPU load',
                    value: sample?.gpuLoad == null
                        ? (gpuRestricted ? 'Restricted' : 'Unavailable')
                        : '${_number(sample?.gpuLoad, decimals: 1)}%',
                    subtitle: sample?.gpuSource == null
                        ? (sample?.gpuModel ?? 'No readable GPU counter')
                        : '${sample?.gpuSource} · ${sample?.gpuModel ?? 'GPU'}',
                    icon: Icons.developer_board_outlined,
                    progress: sample?.gpuLoad == null ? null : sample!.gpuLoad! / 100,
                  ),
                  MetricCard(
                    title: 'GPU clock',
                    value: sample?.gpuFrequencyMhz == null
                        ? 'Unavailable'
                        : '${_number(sample?.gpuFrequencyMhz)} MHz',
                    subtitle: sample?.gpuFrequencyMaxMhz == null
                        ? (sample?.gpuModel ?? 'Vendor counter is protected')
                        : 'Max ${_number(sample?.gpuFrequencyMaxMhz)} MHz',
                    icon: Icons.speed_outlined,
                  ),
                  MetricCard(
                    title: 'System CPU',
                    value: '${_number(sample?.cpuUsage, decimals: 1)}%',
                    subtitle: sample?.cpuGovernor ?? 'All-core utilization',
                    icon: Icons.memory,
                    progress: sample?.cpuUsage == null ? null : sample!.cpuUsage! / 100,
                  ),
                  MetricCard(
                    title: 'CPU clocks',
                    value: '${_number(sample?.cpuFrequencyMhz)} MHz',
                    subtitle: cpuClockSubtitle,
                    icon: Icons.multiline_chart_outlined,
                  ),
                  MetricCard(
                    title: 'Instant power',
                    value: sample?.batteryPowerW == null
                        ? 'Unavailable'
                        : '${_number(sample?.batteryPowerW, decimals: 2)} W',
                    subtitle: sample?.batteryVoltageV == null
                        ? 'Battery-side estimate'
                        : '${_number(sample?.batteryVoltageV, decimals: 2)} V · '
                            '${_number(sample?.batteryCurrentMa)} mA · '
                            '${sample?.batteryPowerSource ?? 'sensor'}',
                    icon: Icons.bolt_outlined,
                  ),
                  MetricCard(
                    title: 'Battery temp',
                    value: sample?.batteryTemperatureC == null
                        ? 'Unavailable'
                        : '${_number(sample?.batteryTemperatureC, decimals: 1)}°C',
                    subtitle: '${_number(sample?.batteryLevel)}% · '
                        '${sample?.batteryCharging == true ? 'Charging' : 'Discharging'}',
                    icon: Icons.battery_charging_full,
                    progress: sample?.batteryLevel == null ? null : sample!.batteryLevel! / 100,
                  ),
                  MetricCard(
                    title: 'System RAM',
                    value: '${_number(sample?.ramUsedMb)} MB',
                    subtitle: '${_number(sample?.ramTotalMb)} MB total',
                    icon: Icons.storage_outlined,
                    progress: sample?.ramUsedMb == null || sample?.ramTotalMb == null
                        ? null
                        : sample!.ramUsedMb! / sample.ramTotalMb!,
                  ),
                  MetricCard(
                    title: 'SoC thermal',
                    value: sample?.socTemperatureC == null
                        ? _thermalLabel(sample?.thermalStatus)
                        : '${_number(sample?.socTemperatureC, decimals: 1)}°C',
                    subtitle: 'Android status: ${_thermalLabel(sample?.thermalStatus)}',
                    icon: Icons.device_thermostat_outlined,
                  ),
                  MetricCard(
                    title: 'Network',
                    value: '↓ ${_number(sample?.rxKbps)} KB/s',
                    subtitle: '↑ ${_number(sample?.txKbps)} KB/s',
                    icon: Icons.swap_vert_circle_outlined,
                  ),
                  MetricCard(
                    title: 'Display',
                    value: '${_number(sample?.refreshRateHz)} Hz',
                    subtitle: '${_number(sample?.frameTimeMs, decimals: 2)} ms frame · '
                        '${sample?.fpsSource ?? 'no FPS source'}',
                    icon: Icons.smartphone_outlined,
                  ),
                ],
              ),
              if (sample?.collectorWarnings.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Some counters are protected by this ROM: '
                      '${sample!.collectorWarnings.take(3).join(' · ')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _thermalLabel(int? value) => switch (value) {
        0 => 'None',
        1 => 'Light',
        2 => 'Moderate',
        3 => 'Severe',
        4 => 'Critical',
        5 => 'Emergency',
        6 => 'Shutdown',
        _ => 'Unknown',
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF39E7D0), Color(0xFF8D7CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF071018)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FPSWatcher',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
              ),
              Text(
                controller.latest?.foregroundPackage ?? 'Waiting for foreground app',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: controller.collectNow,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<AccessMode>(
        segments: AccessMode.values
            .map((mode) => ButtonSegment(value: mode, label: Text(mode.label)))
            .toList(growable: false),
        selected: {controller.accessMode},
        onSelectionChanged: (selection) => controller.setAccessMode(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: 'Mode: ${controller.latest?.accessModeUsed ?? controller.accessMode.label}',
          active: true,
        ),
        _StatusChip(label: '${controller.refreshIntervalMs} ms', active: true),
        _StatusChip(label: 'Usage', active: controller.usageAccess),
        _StatusChip(label: 'Overlay', active: controller.overlayRunning),
        _StatusChip(label: 'Recording', active: controller.recorder.isRecording),
        _StatusChip(label: 'Shizuku', active: controller.shizukuOperational),
        _StatusChip(label: 'Root', active: controller.rootAvailable),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _FpsHero extends StatelessWidget {
  const _FpsHero({required this.sample, required this.history});
  final TelemetrySample? sample;
  final List<double> history;

  String _value(double? value, int decimals) =>
      value == null ? '—' : value.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF102A31), Color(0xFF171C35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REAL-TIME FPS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1.4,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _value(sample?.fps, 1),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
              ),
              Text(
                sample?.fpsSource ?? 'Requires Shizuku or root for another app',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: '1% LOW',
                      value: _value(sample?.onePercentLowFps, 1),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: '0.1% LOW',
                      value: _value(sample?.pointOnePercentLowFps, 1),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'FRAME',
                      value: '${_value(sample?.frameTimeMs, 2)} ms',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Sparkline(values: history.isEmpty ? const [0, 0] : history),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'P95 ${_value(sample?.frameTimeP95Ms, 2)} ms',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
              ),
              const Spacer(),
              Text(
                'P99 ${_value(sample?.frameTimeP99Ms, 2)} ms · '
                '${sample?.totalFrames ?? 0} frames',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
