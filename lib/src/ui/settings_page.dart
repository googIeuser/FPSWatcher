import 'package:flutter/material.dart';
import '../models/telemetry_sample.dart';
import '../state/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final overlay = controller.overlayPreferences;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(
          'Settings & access',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'FPSWatcher uses only Shizuku or Root. Shizuku is the non-root option; Root unlocks the widest process, GPU, thermal and power coverage.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('ACCESS BACKEND'),
        const SizedBox(height: 10),
        RadioGroup<AccessMode>(
          groupValue: controller.accessMode,
          onChanged: (value) {
            if (value != null) controller.setAccessMode(value);
          },
          child: Column(
            children: AccessMode.values
                .map(
                  (mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: RadioListTile<AccessMode>(
                        value: mode,
                        selected: mode == controller.accessMode,
                        title: Text(mode.label),
                        subtitle: Text(_description(mode)),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('DASHBOARD REFRESH'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live UI interval',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '100 ms gives the fastest dashboard response. FPS and low-percentile statistics still use a longer frame window to avoid meaningless spikes.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 100, label: Text('100 ms')),
                      ButtonSegment(value: 200, label: Text('200 ms')),
                      ButtonSegment(value: 500, label: Text('500 ms')),
                      ButtonSegment(value: 1000, label: Text('1 s')),
                    ],
                    selected: {controller.refreshIntervalMs},
                    onSelectionChanged: (values) =>
                        controller.setRefreshInterval(values.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('OVERLAY APPEARANCE'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Square in-game overlay',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The overlay has sharp corners and remembers the position where you drag it.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 16),
                _SliderRow(
                  label: 'Text size',
                  valueLabel: '${overlay.textSizeSp.toStringAsFixed(0)} sp',
                  value: overlay.textSizeSp,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  onChanged: (value) => controller.updateOverlayPreferences(
                    overlay.copyWith(textSizeSp: value),
                  ),
                ),
                _SliderRow(
                  label: 'Opacity',
                  valueLabel: '${(overlay.opacity * 100).round()}%',
                  value: overlay.opacity,
                  min: 0.25,
                  max: 1,
                  divisions: 15,
                  onChanged: (value) => controller.updateOverlayPreferences(
                    overlay.copyWith(opacity: value),
                  ),
                ),
                _SliderRow(
                  label: 'Padding',
                  valueLabel: '${overlay.paddingDp} dp',
                  value: overlay.paddingDp.toDouble(),
                  min: 0,
                  max: 24,
                  divisions: 12,
                  onChanged: (value) => controller.updateOverlayPreferences(
                    overlay.copyWith(paddingDp: value.round()),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Text color', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0xFFFFFFFF, label: Text('White')),
                      ButtonSegment(value: 0xFF39E7D0, label: Text('Cyan')),
                      ButtonSegment(value: 0xFF7CFF84, label: Text('Green')),
                      ButtonSegment(value: 0xFFFFD65A, label: Text('Yellow')),
                    ],
                    selected: {overlay.textColorValue},
                    onSelectionChanged: (values) =>
                        controller.updateOverlayPreferences(
                      overlay.copyWith(textColorValue: values.first),
                    ),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Overlay refresh', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 100, label: Text('100 ms')),
                      ButtonSegment(value: 200, label: Text('200 ms')),
                      ButtonSegment(value: 500, label: Text('500 ms')),
                    ],
                    selected: {overlay.refreshIntervalMs},
                    onSelectionChanged: (values) =>
                        controller.updateOverlayPreferences(
                      overlay.copyWith(refreshIntervalMs: values.first),
                    ),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.resetOverlayPosition,
                    icon: const Icon(Icons.center_focus_strong_outlined),
                    label: const Text('Reset overlay position'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('OVERLAY METRICS'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _MetricSwitch(
                title: 'FPS',
                value: overlay.showFps,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showFps: value),
                ),
              ),
              _MetricSwitch(
                title: '1% low and 0.1% low',
                value: overlay.showLows,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showLows: value),
                ),
              ),
              _MetricSwitch(
                title: 'Frame time and P95',
                value: overlay.showFrameTime,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showFrameTime: value),
                ),
              ),
              _MetricSwitch(
                title: 'System CPU usage',
                value: overlay.showSystemCpu,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showSystemCpu: value),
                ),
              ),
              _MetricSwitch(
                title: 'Game CPU usage',
                value: overlay.showAppCpu,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showAppCpu: value),
                ),
              ),
              _MetricSwitch(
                title: 'CPU frequency',
                value: overlay.showCpuFrequency,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showCpuFrequency: value),
                ),
              ),
              _MetricSwitch(
                title: 'GPU usage',
                value: overlay.showGpuLoad,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showGpuLoad: value),
                ),
              ),
              _MetricSwitch(
                title: 'GPU frequency',
                value: overlay.showGpuFrequency,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showGpuFrequency: value),
                ),
              ),
              _MetricSwitch(
                title: 'Game RAM and RSS',
                value: overlay.showGameRam,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showGameRam: value),
                ),
              ),
              _MetricSwitch(
                title: 'Instant power',
                value: overlay.showPower,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showPower: value),
                ),
              ),
              _MetricSwitch(
                title: 'Battery temperature',
                value: overlay.showBatteryTemperature,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showBatteryTemperature: value),
                ),
              ),
              _MetricSwitch(
                title: 'SoC temperature',
                value: overlay.showSocTemperature,
                onChanged: (value) => controller.updateOverlayPreferences(
                  overlay.copyWith(showSocTemperature: value),
                ),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('PERMISSIONS'),
        const SizedBox(height: 10),
        _PermissionTile(
          icon: Icons.query_stats_outlined,
          title: 'Usage access',
          subtitle: 'Used to identify the foreground game package.',
          granted: controller.usageAccess,
          action: controller.requestUsageAccess,
        ),
        _PermissionTile(
          icon: Icons.picture_in_picture_alt_outlined,
          title: 'Display over other apps',
          subtitle: 'Required for the movable in-game overlay.',
          granted: controller.overlayPermission,
          action: controller.requestOverlayPermission,
        ),
        _PermissionTile(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          subtitle: 'Recommended for the foreground monitor service.',
          granted: controller.notificationPermission,
          action: controller.requestNotificationPermission,
        ),
        _PermissionTile(
          icon: Icons.security_outlined,
          title: 'Root access',
          subtitle: controller.rootAvailable
              ? 'Root shell is operational.'
              : controller.rootInstalled
                  ? 'Approve FPSWatcher in SukiSU / KernelSU / Magisk. ${controller.rootError ?? ''}'
                  : 'No compatible su binary was detected. ${controller.rootError ?? ''}',
          granted: controller.rootAvailable,
          action: controller.requestRootPermission,
        ),
        _PermissionTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Shizuku',
          subtitle: controller.shizukuOperational
              ? 'UserService connected · UID ${controller.shizukuUid}.'
              : controller.shizukuPermission
                  ? 'Permission granted, but UserService is not responding. ${controller.shizukuError ?? ''}'
                  : controller.shizukuAvailable
                      ? 'Shizuku is running. Permission is required.'
                      : 'Shizuku is not running or not installed.',
          granted: controller.shizukuOperational,
          action: controller.requestShizukuPermission,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Runtime',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Rust core',
                  value: controller.rustCore.available ? 'Loaded' : 'Fallback mode',
                ),
                _InfoRow(
                  label: 'Root command',
                  value: controller.rootAvailable ? 'Operational' : 'Unavailable / denied',
                ),
                _InfoRow(
                  label: 'Shizuku service',
                  value: controller.shizukuOperational ? 'Operational' : 'Unavailable',
                ),
                _InfoRow(
                  label: 'Monitor service',
                  value: controller.monitorServiceRunning ? 'Running' : 'Stopped',
                ),
                _InfoRow(
                  label: 'Overlay',
                  value: controller.overlayRunning ? 'Visible' : 'Hidden',
                ),
                _InfoRow(
                  label: 'Selected backend',
                  value: controller.accessMode.label,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.refreshStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh status'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _description(AccessMode mode) => switch (mode) {
        AccessMode.shizuku =>
          'Non-root backend using Shizuku UserService and Android shell permissions.',
        AccessMode.root =>
          'Direct su backend for the widest sysfs, process and thermal access.',
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white54,
              letterSpacing: 1.4,
            ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title),
          value: value,
          onChanged: onChanged,
          dense: true,
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(
            icon,
            color: granted
                ? Theme.of(context).colorScheme.primary
                : Colors.white38,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: granted
              ? const Icon(Icons.check_circle, color: Color(0xFF39E7D0))
              : FilledButton.tonal(
                  onPressed: action,
                  child: const Text('Grant'),
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
