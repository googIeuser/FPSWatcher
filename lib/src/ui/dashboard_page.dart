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
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
    final columns = width >= 760 ? 4 : 2;

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
                      icon: Icon(controller.overlayRunning
                          ? Icons.layers_clear_outlined
                          : Icons.picture_in_picture_alt_outlined),
                      label: Text(controller.overlayRunning ? 'Stop overlay' : 'Start overlay'),
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
              Text('LIVE TELEMETRY', style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white54,
                    letterSpacing: 1.4,
                  )),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: width >= 760 ? 1.25 : 1.04,
                children: [
                  MetricCard(
                    title: 'CPU',
                    value: '${_number(sample?.cpuUsage)}%',
                    subtitle: '${_number(sample?.cpuFrequencyMhz)} MHz',
                    icon: Icons.memory,
                    progress: sample?.cpuUsage == null ? null : sample!.cpuUsage! / 100,
                  ),
                  MetricCard(
                    title: 'GPU',
                    value: sample?.gpuLoad == null ? 'Detected' : '${_number(sample?.gpuLoad)}%',
                    subtitle: sample?.gpuFrequencyMhz == null
                        ? (sample?.gpuModel ?? 'Renderer unavailable')
                        : '${_number(sample?.gpuFrequencyMhz)} MHz · ${sample?.gpuModel ?? ''}',
                    icon: Icons.developer_board_outlined,
                    progress: sample?.gpuLoad == null ? null : sample!.gpuLoad! / 100,
                  ),
                  MetricCard(
                    title: 'Game process',
                    value: sample?.appCpuUsage == null ? 'Waiting' : '${_number(sample?.appCpuUsage)}% CPU',
                    subtitle: sample?.appRamMb == null
                        ? (sample?.foregroundPackage ?? 'Foreground app unavailable')
                        : '${_number(sample?.appRamMb)} MB · PID ${sample?.appPid ?? '—'}',
                    icon: Icons.sports_esports_outlined,
                  ),
                  MetricCard(
                    title: 'RAM',
                    value: '${_number(sample?.ramUsedMb, decimals: 0)} MB',
                    subtitle: '${_number(sample?.ramTotalMb, decimals: 0)} MB total',
                    icon: Icons.storage_outlined,
                    progress: sample?.ramUsedMb == null || sample?.ramTotalMb == null
                        ? null
                        : sample!.ramUsedMb! / sample.ramTotalMb!,
                  ),
                  MetricCard(
                    title: 'Battery',
                    value: '${_number(sample?.batteryLevel)}%',
                    subtitle: '${_number(sample?.batteryTemperatureC, decimals: 1)}°C · '
                        '${_number(sample?.batteryPowerW, decimals: 2)} W',
                    icon: Icons.battery_charging_full,
                    progress: sample?.batteryLevel == null ? null : sample!.batteryLevel! / 100,
                  ),
                  MetricCard(
                    title: 'Network',
                    value: '↓ ${_number(sample?.rxKbps)} KB/s',
                    subtitle: '↑ ${_number(sample?.txKbps)} KB/s',
                    icon: Icons.swap_vert_circle_outlined,
                  ),
                  MetricCard(
                    title: 'Display',
                    value: '${_number(sample?.refreshRateHz, decimals: 0)} Hz',
                    subtitle: '${_number(sample?.frameTimeMs, decimals: 2)} ms frame time',
                    icon: Icons.smartphone_outlined,
                  ),
                  MetricCard(
                    title: 'Storage',
                    value: '${_number(sample?.storageUsedGb, decimals: 1)} GB',
                    subtitle: '${_number(sample?.storageTotalGb, decimals: 1)} GB total',
                    icon: Icons.sd_storage_outlined,
                    progress: sample?.storageUsedGb == null || sample?.storageTotalGb == null
                        ? null
                        : sample!.storageUsedGb! / sample.storageTotalGb!,
                  ),
                  MetricCard(
                    title: 'SoC thermal',
                    value: sample?.socTemperatureC == null
                        ? _thermalLabel(sample?.thermalStatus)
                        : '${_number(sample?.socTemperatureC, decimals: 1)}°C',
                    subtitle: 'Android status: ${_thermalLabel(sample?.thermalStatus)}',
                    icon: Icons.device_thermostat_outlined,
                  ),
                ],
              ),
              if (controller.lastError != null) ...[
                const SizedBox(height: 14),
                Text(
                  controller.lastError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
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
              Text('FPSWatcher', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  )),
              Text(
                controller.latest?.foregroundPackage ?? 'Waiting for foreground app',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
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
        _StatusChip(label: 'Usage', active: controller.usageAccess),
        _StatusChip(label: 'Overlay', active: controller.overlayRunning),
        _StatusChip(label: 'Recording', active: controller.recorder.isRecording),
        _StatusChip(label: 'Shizuku', active: controller.shizukuPermission),
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
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _FpsHero extends StatelessWidget {
  const _FpsHero({required this.sample, required this.history});
  final TelemetrySample? sample;
  final List<double> history;

  String _value(double? value, int decimals) => value == null ? '—' : value.toStringAsFixed(decimals);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT FPS', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white54,
                        letterSpacing: 1.4,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    _value(sample?.fps, 1),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              _MiniStat(label: 'P90', value: _value(sample?.p90Fps, 1)),
              const SizedBox(width: 18),
              _MiniStat(label: 'P99', value: _value(sample?.p99Fps, 1)),
            ],
          ),
          const SizedBox(height: 12),
          Sparkline(values: history.isEmpty ? const [0, 0] : history),
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
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38)),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
