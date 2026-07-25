import 'package:flutter/material.dart';
import '../state/app_controller.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final samples = controller.recorder.samples;
    final fps = samples.map((sample) => sample.fps).whereType<double>().toList();
    final average = fps.isEmpty ? null : fps.reduce((a, b) => a + b) / fps.length;
    final minimum = fps.isEmpty ? null : fps.reduce((a, b) => a < b ? a : b);
    final maximum = fps.isEmpty ? null : fps.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('Session recorder', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            )),
        const SizedBox(height: 6),
        Text(
          'Record one native telemetry sample per second in the foreground service, then export the complete session as CSV.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: controller.recorder.isRecording
                            ? Theme.of(context).colorScheme.error
                            : Colors.white24,
                        shape: BoxShape.circle,
                        boxShadow: controller.recorder.isRecording
                            ? [BoxShadow(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5), blurRadius: 14)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.recorder.isRecording ? 'Recording in progress' : 'Recorder is idle',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${controller.recorder.totalCount} samples'),
                  ],
                ),
                const SizedBox(height: 18),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Stat(label: controller.recorder.isRecording ? 'Recent avg' : 'Average', value: average)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: controller.recorder.isRecording ? 'Recent min' : 'Minimum', value: minimum)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: controller.recorder.isRecording ? 'Recent max' : 'Maximum', value: maximum)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: samples.isEmpty
              ? null
              : () async {
                  try {
                    await controller.exportCsv();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CSV export completed.')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('CSV export failed: $error')),
                      );
                    }
                  }
                },
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('Save session as CSV'),
        ),
        const SizedBox(height: 22),
        Text('RECENT SAMPLES', style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white54,
              letterSpacing: 1.4,
            )),
        const SizedBox(height: 10),
        if (samples.isEmpty)
          const _EmptySession()
        else
          ...samples.reversed.take(30).map(
                (sample) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(sample.fps?.toStringAsFixed(0) ?? '—'),
                      ),
                      title: Text(sample.foregroundPackage ?? 'Unknown package'),
                      subtitle: Text(
                        'CPU ${sample.cpuUsage?.toStringAsFixed(0) ?? '—'}% · '
                        'GPU ${sample.gpuLoad?.toStringAsFixed(0) ?? '—'}% · '
                        'App ${sample.appRamMb?.toStringAsFixed(0) ?? '—'} MB · '
                        '${sample.batteryTemperatureC?.toStringAsFixed(1) ?? '—'}°C',
                      ),
                      trailing: Text(
                        '${sample.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${sample.timestamp.minute.toString().padLeft(2, '0')}:'
                        '${sample.timestamp.second.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          children: [
            Text(value?.toStringAsFixed(1) ?? '—', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  const _EmptySession();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.data_exploration_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text('No recorded samples yet.'),
          ],
        ),
      ),
    );
  }
}
