import 'package:flutter/material.dart';
import '../models/telemetry_sample.dart';
import '../state/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('Settings & access', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            )),
        const SizedBox(height: 6),
        Text(
          'Standard mode collects every public Android counter it can read. Shizuku adds real game FPS, process CPU/RAM and any GPU nodes permitted to the shell user; Root unlocks the widest sysfs coverage.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 18),
        Text('ACCESS MODE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4)),
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
        Text('REFRESH RATE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live UI interval', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Lightweight Android counters refresh at this interval. Privileged FPS, process and GPU probes are throttled to 250 ms to avoid affecting the game.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 250, label: Text('250 ms')),
                    ButtonSegment(value: 500, label: Text('500 ms')),
                    ButtonSegment(value: 1000, label: Text('1 s')),
                  ],
                  selected: {controller.refreshIntervalMs},
                  onSelectionChanged: (values) => controller.setRefreshInterval(values.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('PERMISSIONS', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        _PermissionTile(
          icon: Icons.query_stats_outlined,
          title: 'Usage access',
          subtitle: 'Required to identify the foreground game package.',
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
          subtitle: 'Recommended for a visible foreground monitor notification.',
          granted: controller.notificationPermission,
          action: controller.requestNotificationPermission,
        ),
        _PermissionTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Shizuku',
          subtitle: controller.shizukuOperational
              ? 'UserService connected · UID ${controller.shizukuUid}.'
              : controller.shizukuPermission
                  ? 'Permission granted, but UserService is not responding. Tap to reconnect.'
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
                Text('Runtime', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _InfoRow(label: 'Rust core', value: controller.rustCore.available ? 'Loaded' : 'Fallback mode'),
                _InfoRow(label: 'Root binary', value: controller.rootInstalled ? 'Detected' : 'Not detected'),
                _InfoRow(label: 'Root command', value: controller.rootAvailable ? 'Operational' : 'Unavailable / denied'),
                _InfoRow(label: 'Shizuku service', value: controller.shizukuOperational ? 'Operational' : 'Unavailable'),
                _InfoRow(label: 'Monitor service', value: controller.monitorServiceRunning ? 'Running' : 'Stopped'),
                _InfoRow(label: 'Overlay', value: controller.overlayRunning ? 'Visible' : 'Hidden'),
                _InfoRow(label: 'Recorder', value: controller.recorder.isRecording ? 'Recording' : 'Idle'),
                _InfoRow(label: 'Selected backend', value: controller.accessMode.label),
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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'GPU load and frequency are not public standardized Android APIs. FPSWatcher checks Qualcomm KGSL, Mali/devfreq, PowerVR and vendor paths in Standard, Shizuku and Root order. When a ROM blocks every readable counter, the app keeps the GPU model but marks load and clock as unavailable instead of inventing values.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }

  String _description(AccessMode mode) => switch (mode) {
        AccessMode.auto => 'Prefer Root when granted, then Shizuku, then Standard mode.',
        AccessMode.standard => 'No privileged access. Maximum safe Android API coverage.',
        AccessMode.shizuku => 'Use Android shell/root identity through Shizuku UserService.',
        AccessMode.root => 'Use su directly for the widest sysfs access.',
      };
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
          leading: Icon(icon, color: granted ? Theme.of(context).colorScheme.primary : Colors.white38),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: granted
              ? const Icon(Icons.check_circle, color: Color(0xFF39E7D0))
              : FilledButton.tonal(onPressed: action, child: const Text('Grant')),
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
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
