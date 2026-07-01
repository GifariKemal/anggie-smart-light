import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/models/telemetry.dart';
import 'package:saqelar/services/device_scope.dart';
import 'package:saqelar/services/device_simulator.dart';
import 'package:saqelar/services/sfx.dart';
import 'package:saqelar/widgets/hud_widgets.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = DeviceScope.of(context);
    final t = sim.latest;
    final safety = AppTheme.safetyColor(t?.safetyState ?? 'ok');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control panel'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Stack(children: [
        const HudGridBackground(),
        SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Live readout strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  _live('Lux', t?.lux.toStringAsFixed(0) ?? '--'),
                  _live('Dimmer', '${t?.dimmerPct ?? 0}%'),
                  _live('Current', '${t?.currentMa.toStringAsFixed(0) ?? '--'}mA'),
                  StatusBadge(
                    label: (t?.safetyState ?? 'ok').toUpperCase(),
                    color: safety,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const _Group(label: 'Operating mode'),
            const SizedBox(height: 10),
            _ModeSelector(sim: sim),
            const SizedBox(height: 8),
            Text(
              _modeHint(sim.mode),
              style: const TextStyle(color: AppTheme.faint, fontSize: 12.5),
            ),

            const SizedBox(height: 22),
            const _Group(label: 'Setpoint'),
            const SizedBox(height: 6),
            _SliderRow(
              title: 'Target lux',
              value: sim.targetLux,
              min: 0,
              max: 1000,
              divisions: 100,
              suffix: ' lux',
              enabled: sim.mode == DeviceMode.auto,
              onChanged: sim.setTargetLux,
            ),
            _SliderRow(
              title: 'Manual dimmer',
              value: sim.manualDimmer.toDouble(),
              min: 0,
              max: FirmwareConstants.dimmerMaxPct.toDouble(),
              divisions: FirmwareConstants.dimmerMaxPct,
              suffix: ' %',
              enabled: sim.mode == DeviceMode.manual,
              onChanged: (v) => sim.setManualDimmer(v.round()),
            ),

            const SizedBox(height: 22),
            const _Group(label: 'PID tuning'),
            const SizedBox(height: 6),
            _SliderRow(
              title: 'Kp',
              value: sim.kp,
              min: 0,
              max: 1,
              divisions: 100,
              fractionDigits: 2,
              enabled: sim.mode == DeviceMode.auto,
              onChanged: (v) => sim.setPid(kp: v),
            ),
            _SliderRow(
              title: 'Ki',
              value: sim.ki,
              min: 0,
              max: 1,
              divisions: 100,
              fractionDigits: 2,
              enabled: sim.mode == DeviceMode.auto,
              onChanged: (v) => sim.setPid(ki: v),
            ),
            _SliderRow(
              title: 'Kd',
              value: sim.kd,
              min: 0,
              max: 1,
              divisions: 100,
              fractionDigits: 2,
              enabled: sim.mode == DeviceMode.auto,
              onChanged: (v) => sim.setPid(kd: v),
            ),

            const SizedBox(height: 22),
            const _Group(label: 'Demo scenarios'),
            const SizedBox(height: 6),
            _ToggleRow(
              title: 'Simulate daylight',
              subtitle: 'Force LDR above ${FirmwareConstants.ldrDaylightRaw} → standby',
              value: sim.simulateDaylight,
              onChanged: sim.toggleDaylight,
              color: AppTheme.warning,
            ),
            _ToggleRow(
              title: 'Simulate overcurrent',
              subtitle: 'Force current past ${FirmwareConstants.maxSafeCurrentMa.toStringAsFixed(0)} mA → fault',
              value: sim.simulateOvercurrent,
              onChanged: sim.toggleOvercurrent,
              color: AppTheme.danger,
            ),

            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    sim.isLive
                        ? Icons.sensors_rounded
                        : Icons.shield_moon_rounded,
                    color: sim.isLive ? AppTheme.accent : AppTheme.faint,
                    size: 16,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      sim.isLive
                          ? 'Terhubung ke device: perubahan dikirim live ke command topic. Safety on-device tetap berkuasa.'
                          : 'Mode simulator. Sambungkan device di Settings agar kontrol dikirim ke perangkat.',
                      style: const TextStyle(
                          color: AppTheme.faint, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ]),
    );
  }

  Widget _live(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTheme.monoLabel.copyWith(fontSize: 9)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ],
    ),
  );

  static String _modeHint(DeviceMode m) => switch (m) {
    DeviceMode.auto =>
      'PID drives the dimmer to hold the target lux automatically.',
    DeviceMode.manual => 'Dimmer is held at your manual setting.',
    DeviceMode.off => 'Relay open — output disabled.',
  };
}

class _Group extends StatelessWidget {
  const _Group({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => SectionLabel(label);
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.sim});
  final DeviceSimulator sim;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DeviceMode.values.map((m) {
        final selected = sim.mode == m;
        final color = m == DeviceMode.off ? AppTheme.danger : AppTheme.accent;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: m == DeviceMode.off ? 0 : 8),
            child: Semantics(
              button: true,
              selected: selected,
              label: 'Mode ${m.label}',
              child: PressableScale(
              scale: 0.97,
              onTap: () {
                Sfx.instance.select();
                sim.setMode(m);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.14)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? color : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      switch (m) {
                        DeviceMode.auto => Icons.auto_mode_rounded,
                        DeviceMode.manual => Icons.pan_tool_rounded,
                        DeviceMode.off => Icons.power_settings_new_rounded,
                      },
                      color: selected ? color : AppTheme.faint,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppTheme.ink : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
    this.suffix = '',
    this.fractionDigits = 0,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final String suffix;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(fractionDigits)}$suffix',
                style: const TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? (_) => Sfx.instance.tap() : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? color : AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.faint, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              v ? Sfx.instance.toggleOn() : Sfx.instance.toggleOff();
              onChanged(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }
}
