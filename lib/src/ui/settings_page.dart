import 'package:flutter/material.dart';
import '../models/overlay_preferences.dart';
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
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text('Tune the privileged backend, dashboard sampling and every in-game overlay metric.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        _Label('TELEMETRY BACKEND'),
        const SizedBox(height: 9),
        SegmentedButton<AccessMode>(
          segments: const [
            ButtonSegment(value: AccessMode.shizuku, label: Text('Shizuku'), icon: Icon(Icons.admin_panel_settings_outlined)),
            ButtonSegment(value: AccessMode.root, label: Text('Root'), icon: Icon(Icons.security_outlined)),
          ],
          selected: {controller.accessMode},
          onSelectionChanged: (selection) => controller.setAccessMode(selection.first),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              controller.accessMode == AccessMode.root
                  ? 'Root is the widest backend for sysfs, thermal zones, process scheduling, GPU devfreq and raw kernel telemetry.'
                  : 'Shizuku runs privileged shell telemetry without root. Availability still depends on Android and vendor restrictions.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Label('DASHBOARD SAMPLING'),
        const SizedBox(height: 9),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                children: [100, 200, 500, 1000].map((ms) => ChoiceChip(
                      label: Text('$ms ms'),
                      selected: controller.refreshIntervalMs == ms,
                      onSelected: (_) => controller.setRefreshInterval(ms),
                    )).toList(growable: false),
              ),
              const SizedBox(height: 8),
              Text('Fast counters are sampled frequently; expensive process, memory and network probes are internally rate-limited.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _Label('OVERLAY PRESETS'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Preset('Minimal', 'minimal', controller, overlay),
            _Preset('Performance', 'performance', controller, overlay),
            _Preset('Thermal', 'thermal', controller, overlay),
            _Preset('Battery', 'battery', controller, overlay),
            _Preset('Network', 'network', controller, overlay),
            _Preset('Full telemetry', 'full', controller, overlay),
          ],
        ),
        const SizedBox(height: 14),
        _OverlayPreview(preferences: overlay),
        const SizedBox(height: 14),
        _Label('OVERLAY APPEARANCE'),
        const SizedBox(height: 9),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _SliderRow(
                label: 'Text size',
                valueLabel: '${overlay.textSizeSp.toStringAsFixed(0)} sp',
                value: overlay.textSizeSp,
                min: 10,
                max: 24,
                divisions: 14,
                onChanged: (value) => controller.updateOverlayPreferences(overlay.copyWith(textSizeSp: value)),
              ),
              _SliderRow(
                label: 'Background opacity',
                valueLabel: '${(overlay.opacity * 100).round()}%',
                value: overlay.opacity,
                min: .15,
                max: 1,
                divisions: 17,
                onChanged: (value) => controller.updateOverlayPreferences(overlay.copyWith(opacity: value)),
              ),
              _SliderRow(
                label: 'Padding',
                valueLabel: '${overlay.paddingDp} dp',
                value: overlay.paddingDp.toDouble(),
                min: 0,
                max: 24,
                divisions: 24,
                onChanged: (value) => controller.updateOverlayPreferences(overlay.copyWith(paddingDp: value.round())),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Expanded(child: Text('Layout')),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'vertical', label: Text('Vertical')), ButtonSegment(value: 'horizontal', label: Text('Horizontal'))],
                  selected: {overlay.layoutMode},
                  onSelectionChanged: (values) => controller.updateOverlayPreferences(overlay.copyWith(layoutMode: values.first)),
                ),
              ]),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Adaptive warning colors'),
                subtitle: const Text('Changes the overlay text color for thermal or stability warnings.'),
                value: overlay.adaptiveColors,
                onChanged: (value) => controller.updateOverlayPreferences(overlay.copyWith(adaptiveColors: value)),
              ),
              const Divider(),
              Row(children: [
                const Expanded(child: Text('Overlay refresh')),
                ...[100, 200, 500].map((ms) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(label: Text('$ms'), selected: overlay.refreshIntervalMs == ms, onSelected: (_) => controller.updateOverlayPreferences(overlay.copyWith(refreshIntervalMs: ms))),
                    )),
              ]),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: controller.resetOverlayPosition, icon: const Icon(Icons.center_focus_strong), label: const Text('Reset overlay position'))),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _Label('OVERLAY METRICS'),
        const SizedBox(height: 9),
        Card(
          child: Column(children: [
            _Switch('Show only with detected game', overlay.showOnlyWhenGameDetected, (v) => controller.updateOverlayPreferences(overlay.copyWith(showOnlyWhenGameDetected: v))),
            _Switch('FPS', overlay.showFps, (v) => controller.updateOverlayPreferences(overlay.copyWith(showFps: v))),
            _Switch('5% low', overlay.showFivePercentLow, (v) => controller.updateOverlayPreferences(overlay.copyWith(showFivePercentLow: v))),
            _Switch('1% and 0.1% low', overlay.showLows, (v) => controller.updateOverlayPreferences(overlay.copyWith(showLows: v))),
            _Switch('Frame time / P95 / P99', overlay.showFrameTime, (v) => controller.updateOverlayPreferences(overlay.copyWith(showFrameTime: v))),
            _Switch('Stability and stutters', overlay.showStability, (v) => controller.updateOverlayPreferences(overlay.copyWith(showStability: v))),
            _Switch('Estimated dropped frames', overlay.showDroppedFrames, (v) => controller.updateOverlayPreferences(overlay.copyWith(showDroppedFrames: v))),
            _Switch('System CPU usage', overlay.showSystemCpu, (v) => controller.updateOverlayPreferences(overlay.copyWith(showSystemCpu: v))),
            _Switch('Game CPU usage', overlay.showAppCpu, (v) => controller.updateOverlayPreferences(overlay.copyWith(showAppCpu: v))),
            _Switch('CPU frequency', overlay.showCpuFrequency, (v) => controller.updateOverlayPreferences(overlay.copyWith(showCpuFrequency: v))),
            _Switch('Per-core CPU telemetry', overlay.showCpuCores, (v) => controller.updateOverlayPreferences(overlay.copyWith(showCpuCores: v))),
            _Switch('CPU throttling', overlay.showCpuThrottle, (v) => controller.updateOverlayPreferences(overlay.copyWith(showCpuThrottle: v))),
            _Switch('GPU usage', overlay.showGpuLoad, (v) => controller.updateOverlayPreferences(overlay.copyWith(showGpuLoad: v))),
            _Switch('GPU frequency', overlay.showGpuFrequency, (v) => controller.updateOverlayPreferences(overlay.copyWith(showGpuFrequency: v))),
            _Switch('GPU throttling', overlay.showGpuThrottle, (v) => controller.updateOverlayPreferences(overlay.copyWith(showGpuThrottle: v))),
            _Switch('Game RAM / RSS', overlay.showGameRam, (v) => controller.updateOverlayPreferences(overlay.copyWith(showGameRam: v))),
            _Switch('Swap / ZRAM / memory pressure', overlay.showMemory, (v) => controller.updateOverlayPreferences(overlay.copyWith(showMemory: v))),
            _Switch('Process scheduler details', overlay.showProcessDetails, (v) => controller.updateOverlayPreferences(overlay.copyWith(showProcessDetails: v))),
            _Switch('Instant power', overlay.showPower, (v) => controller.updateOverlayPreferences(overlay.copyWith(showPower: v))),
            _Switch('FPS per watt', overlay.showEfficiency, (v) => controller.updateOverlayPreferences(overlay.copyWith(showEfficiency: v))),
            _Switch('Battery drain rate', overlay.showBatteryDrain, (v) => controller.updateOverlayPreferences(overlay.copyWith(showBatteryDrain: v))),
            _Switch('Battery temperature', overlay.showBatteryTemperature, (v) => controller.updateOverlayPreferences(overlay.copyWith(showBatteryTemperature: v))),
            _Switch('SoC temperature', overlay.showSocTemperature, (v) => controller.updateOverlayPreferences(overlay.copyWith(showSocTemperature: v))),
            _Switch('Thermal status / score', overlay.showThermalStatus, (v) => controller.updateOverlayPreferences(overlay.copyWith(showThermalStatus: v))),
            _Switch('Ping / jitter / packet loss', overlay.showNetwork, (v) => controller.updateOverlayPreferences(overlay.copyWith(showNetwork: v))),
            _Switch('Wi-Fi telemetry', overlay.showWifi, (v) => controller.updateOverlayPreferences(overlay.copyWith(showWifi: v))),
            _Switch('FPSWatcher overhead', overlay.showMonitorOverhead, (v) => controller.updateOverlayPreferences(overlay.copyWith(showMonitorOverhead: v)), last: true),
          ]),
        ),
        const SizedBox(height: 18),
        _Label('PERMISSIONS'),
        const SizedBox(height: 9),
        _Permission(icon: Icons.query_stats_outlined, title: 'Usage access', subtitle: 'Identifies the foreground game package.', granted: controller.usageAccess, action: controller.requestUsageAccess),
        _Permission(icon: Icons.picture_in_picture_alt_outlined, title: 'Display over other apps', subtitle: 'Required for the in-game overlay.', granted: controller.overlayPermission, action: controller.requestOverlayPermission),
        _Permission(icon: Icons.notifications_active_outlined, title: 'Notifications', subtitle: 'Keeps the monitor service visible to Android.', granted: controller.notificationPermission, action: controller.requestNotificationPermission),
        _Permission(icon: Icons.security_outlined, title: 'Root access', subtitle: controller.rootAvailable ? 'Root shell is operational.' : controller.rootError ?? 'Approve FPSWatcher in your root manager.', granted: controller.rootAvailable, action: controller.requestRootPermission),
        _Permission(icon: Icons.admin_panel_settings_outlined, title: 'Shizuku', subtitle: controller.shizukuOperational ? 'UserService connected · UID ${controller.shizukuUid}.' : controller.shizukuError ?? 'Start Shizuku and grant permission.', granted: controller.shizukuOperational, action: controller.requestShizukuPermission),
      ],
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset(this.label, this.name, this.controller, this.preferences);
  final String label;
  final String name;
  final AppController controller;
  final OverlayPreferences preferences;
  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: () => controller.updateOverlayPreferences(preferences.preset(name)), child: Text(label));
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.4));
}

class _Switch extends StatelessWidget {
  const _Switch(this.title, this.value, this.onChanged, {this.last = false});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;
  @override
  Widget build(BuildContext context) => Column(children: [
        SwitchListTile.adaptive(title: Text(title), value: value, onChanged: onChanged),
        if (!last) const Divider(height: 1),
      ]);
}

class _Permission extends StatelessWidget {
  const _Permission({required this.icon, required this.title, required this.subtitle, required this.granted, required this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final Future<void> Function() action;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: granted ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: granted ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : TextButton(onPressed: action, child: const Text('Grant')),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.valueLabel, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [Expanded(child: Text(label)), Text(valueLabel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ]);
}

class _OverlayPreview extends StatelessWidget {
  const _OverlayPreview({required this.preferences});
  final OverlayPreferences preferences;
  @override
  Widget build(BuildContext context) {
    final chunks = <String>[];
    if (preferences.showFps) chunks.add('FPS 120.0');
    if (preferences.showFivePercentLow) chunks.add('5% 108.1');
    if (preferences.showLows) chunks.add('1% 102.4  0.1% 88.0');
    if (preferences.showFrameTime) chunks.add('FRAME 8.33  P99 12.4');
    if (preferences.showStability) chunks.add('STAB 93.2%  S25 2');
    if (preferences.showSystemCpu || preferences.showCpuFrequency) chunks.add('CPU 48%  3302 MHz');
    if (preferences.showGpuLoad || preferences.showGpuFrequency) chunks.add('GPU 82%  903 MHz');
    if (preferences.showPower) chunks.add('PWR 5.82 W  BAT 39.1°C');
    if (preferences.showNetwork) chunks.add('PING 21 ms  JIT 2.1  LOSS 0%');
    final text = chunks.join(preferences.layoutMode == 'horizontal' ? '   |   ' : '\n');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LIVE OVERLAY PREVIEW', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: EdgeInsets.all(preferences.paddingDp.toDouble()),
              color: Colors.black.withValues(alpha: preferences.opacity),
              child: Text(text.isEmpty ? 'FPSWatcher' : text, style: TextStyle(fontSize: preferences.textSizeSp, color: preferences.textColor, fontFamily: 'monospace')),
            ),
          ),
        ]),
      ),
    );
  }
}
