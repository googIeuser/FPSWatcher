import 'package:flutter/material.dart';
import '../models/telemetry_sample.dart';
import '../state/app_controller.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final samples = controller.recorder.samples;
    final summary = controller.recorder.summarize();
    final events = _events(context, samples);
    String f(Object? value, [int digits = 1]) =>
        value is num ? value.toStringAsFixed(digits) : '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('Session analysis', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text(
          'Record a native telemetry session and analyze frame pacing, lows, efficiency, thermals, memory and network events.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: controller.recorder.isRecording ? Theme.of(context).colorScheme.error : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(controller.recorder.isRecording ? 'Recording in progress' : 'Recorder is idle', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${controller.recorder.totalCount} samples'),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.toggleRecording,
                    icon: Icon(controller.recorder.isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record),
                    label: Text(controller.recorder.isRecording ? 'Stop recording' : 'Start recording'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SummaryGrid(children: [
          _Stat('Average FPS', f(summary['averageFps'])),
          _Stat('5% low', f(summary['averageFivePercentLow'])),
          _Stat('1% low', f(summary['averageOnePercentLow'])),
          _Stat('0.1% low', f(summary['averagePointOnePercentLow'])),
          _Stat('Stability', '${f(summary['averageStability'])}%'),
          _Stat('Frame pacing', '${f(summary['averageFramePacing'])}%'),
          _Stat('Performance stability', '${f(summary['averagePerformanceStability'])}%'),
          _Stat('FPS / watt', f(summary['averageFpsPerWatt'], 2)),
          _Stat('Average power', '${f(summary['averagePowerW'], 2)} W'),
          _Stat('Peak power', '${f(summary['peakPowerW'], 2)} W'),
          _Stat('Peak battery', '${f(summary['peakBatteryTemperatureC'])} °C'),
          _Stat('Peak SoC', '${f(summary['peakSocTemperatureC'])} °C'),
          _Stat('Stutter events', '${summary['stutterEvents'] ?? 0}'),
          _Stat('Frozen frames', '${summary['frozenFrameEvents'] ?? 0}'),
          _Stat('FPS drift', '${f(summary['fpsDriftPercent'])}%'),
          _Stat('Thermal samples', '${summary['thermalThrottleSamples'] ?? 0}'),
        ]),
        const SizedBox(height: 14),
        _ComparisonCard(summary: summary),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ExportButton(label: 'CSV', icon: Icons.table_view_outlined, enabled: samples.isNotEmpty, action: controller.exportCsv),
            _ExportButton(label: 'JSON', icon: Icons.data_object_outlined, enabled: samples.isNotEmpty, action: controller.exportJson),
            _ExportButton(label: 'HTML report', icon: Icons.description_outlined, enabled: samples.isNotEmpty, action: controller.exportHtml),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: controller.recorder.isRecording ? () => _addMarker(context) : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Add session marker'),
          ),
        ),
        const SizedBox(height: 22),
        Text('EVENT TIMELINE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const _Empty(text: 'No performance events detected yet.')
        else
          ...events.take(40).map((event) => _EventTile(event: event)),
        const SizedBox(height: 22),
        Text('RECENT SAMPLES', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        if (samples.isEmpty)
          const _Empty(text: 'No recorded samples yet.')
        else
          ...samples.reversed.take(30).map((sample) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text(sample.fps?.toStringAsFixed(0) ?? '—')),
                  title: Text(sample.foregroundPackage ?? 'Unknown package'),
                  subtitle: Text(
                    '1% ${sample.onePercentLowFps?.toStringAsFixed(0) ?? '—'} · '
                    'P99 ${sample.frameTimeP99Ms?.toStringAsFixed(1) ?? '—'} ms · '
                    'GPU ${sample.gpuLoad?.toStringAsFixed(0) ?? '—'}% · '
                    '${sample.batteryPowerW?.toStringAsFixed(2) ?? '—'} W · '
                    '${sample.batteryTemperatureC?.toStringAsFixed(1) ?? '—'}°C',
                  ),
                  trailing: Text(_clock(sample.timestamp)),
                ),
              )),
      ],
    );
  }

  Future<void> _addMarker(BuildContext context) async {
    final textController = TextEditingController(text: 'Gameplay marker');
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add session marker'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'What happened here?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, textController.text), child: const Text('Add marker')),
        ],
      ),
    );
    textController.dispose();
    if (label != null && label.trim().isNotEmpty) await controller.addSessionMarker(label);
  }

  List<_PerformanceEvent> _events(BuildContext context, List<TelemetrySample> samples) {
    final events = <_PerformanceEvent>[];
    bool thermalActive = false;
    bool fpsDropActive = false;
    bool networkActive = false;
    bool heavyStutterActive = false;
    for (final sample in samples) {
      if (sample.eventType == 'marker') {
        events.add(_PerformanceEvent(sample.timestamp, 'Marker', sample.eventLabel ?? 'Manual marker', Icons.bookmark_outline, Theme.of(context).colorScheme.primary));
        continue;
      }
      final thermal = sample.thermalThrottling == true;
      if (thermal && !thermalActive) {
        events.add(_PerformanceEvent(sample.timestamp, 'Thermal throttling', 'CPU/GPU frequency headroom dropped under load.', Icons.device_thermostat_outlined, Theme.of(context).colorScheme.error));
      }
      thermalActive = thermal;

      final refresh = sample.refreshRateHz;
      final fps = sample.fps;
      final fpsDrop = fps != null && refresh != null && fps < refresh * .65;
      if (fpsDrop && !fpsDropActive) {
        events.add(_PerformanceEvent(sample.timestamp, 'FPS drop', '${fps.toStringAsFixed(1)} FPS on ${refresh.toStringAsFixed(0)} Hz display.', Icons.trending_down, Theme.of(context).colorScheme.tertiary));
      }
      fpsDropActive = fpsDrop;

      final network = (sample.networkPacketLossPercent ?? 0) >= 3 || (sample.networkJitterMs ?? 0) >= 20;
      if (network && !networkActive) {
        events.add(_PerformanceEvent(sample.timestamp, 'Network spike', 'Ping ${sample.networkPingMs?.toStringAsFixed(1) ?? '—'} ms · jitter ${sample.networkJitterMs?.toStringAsFixed(1) ?? '—'} ms · loss ${sample.networkPacketLossPercent?.toStringAsFixed(1) ?? '—'}%.', Icons.network_ping_outlined, Theme.of(context).colorScheme.secondary));
      }
      networkActive = network;

      final heavyStutter = (sample.stutter100msCount ?? 0) > 0;
      if (heavyStutter && !heavyStutterActive) {
        events.add(_PerformanceEvent(sample.timestamp, 'Heavy stutter', '${sample.stutter100msCount} frame(s) exceeded 100 ms in the rolling window.', Icons.bolt_outlined, Theme.of(context).colorScheme.errorContainer));
      }
      heavyStutterActive = heavyStutter;
    }
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  static String _clock(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 850 ? 4 : width >= 600 ? 3 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: children,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ),
      );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.icon, required this.enabled, required this.action});
  final String label;
  final IconData icon;
  final bool enabled;
  final Future<String?> Function() action;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: !enabled
            ? null
            : () async {
                try {
                  await action();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label export completed.')));
                } catch (error) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label export failed: $error')));
                }
              },
        icon: Icon(icon),
        label: Text(label),
      );
}


class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.summary});
  final Map<String, Object?> summary;

  String f(Object? value, [int digits = 1]) => value is num ? value.toStringAsFixed(digits) : '—';

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SESSION DRIFT', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _DriftValue(label: 'First half FPS', value: f(summary['firstHalfFps']))),
                  Expanded(child: _DriftValue(label: 'Second half FPS', value: f(summary['secondHalfFps']))),
                  Expanded(child: _DriftValue(label: 'FPS change', value: '${f(summary['fpsDriftPercent'])}%')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Power: ${f(summary['firstHalfPowerW'], 2)} W → ${f(summary['secondHalfPowerW'], 2)} W',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _DriftValue extends StatelessWidget {
  const _DriftValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      );
}

class _PerformanceEvent {
  const _PerformanceEvent(this.timestamp, this.title, this.subtitle, this.icon, this.color);
  final DateTime timestamp;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final _PerformanceEvent event;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(event.icon, color: event.color),
          title: Text(event.title),
          subtitle: Text(event.subtitle),
          trailing: Text(SessionPage._clock(event.timestamp)),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(text, style: const TextStyle(color: Colors.white54))),
        ),
      );
}
