import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/models/telemetry.dart';
import 'package:saqelar/services/device_scope.dart';
import 'package:saqelar/services/device_simulator.dart';
import 'package:saqelar/services/sfx.dart';
import 'package:saqelar/widgets/hud_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _broker;
  late final TextEditingController _topic;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final sim = DeviceScope.of(context);
    _broker = TextEditingController(
        text: sim.broker ?? FirmwareConstants.mqttBroker);
    _topic = TextEditingController(
        text: sim.topic ?? FirmwareConstants.mqttTelemetryTopic);
  }

  @override
  void dispose() {
    _broker.dispose();
    _topic.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.monoLabel),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: const TextStyle(
              fontFamily: AppTheme.fontMono, color: AppTheme.ink, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.faint),
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _logRow(LogEntry e) {
    final c = switch (e.level) {
      'ok' => AppTheme.accent,
      'warn' => AppTheme.warning,
      'err' => AppTheme.danger,
      _ => AppTheme.muted,
    };
    String two(int v) => v.toString().padLeft(2, '0');
    final t = '${two(e.time.hour)}:${two(e.time.minute)}:${two(e.time.second)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: AppTheme.monoLabel.copyWith(fontSize: 10)),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e.message,
                style: const TextStyle(color: AppTheme.ink, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = DeviceScope.of(context);
    final live = sim.isLive;
    final color = live
        ? AppTheme.accent
        : (sim.isSimulated ? AppTheme.info : AppTheme.warning);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device connection'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Stack(
        children: [
          const HudGridBackground(),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.rMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('STATUS', style: AppTheme.monoLabel),
                            const SizedBox(height: 6),
                            Text(
                              sim.connectionStatus,
                              style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: live
                            ? 'DEVICE'
                            : (sim.isSimulated ? 'SIM' : 'LINKING'),
                        color: color,
                        pulse: live,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                _field('MQTT BROKER', _broker, 'broker.emqx.io'),
                _field('TELEMETRY TOPIC', _topic,
                    'suriota/anggie-001/telemetry'),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () {
                            Sfx.instance.success();
                            sim.connect(_broker.text, _topic.text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menyambung ke broker MQTT ...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.sensors_rounded),
                          label: const Text('Sambungkan'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: sim.isSimulated
                            ? null
                            : () {
                                Sfx.instance.tap();
                                sim.disconnect();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.muted,
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: const Text('Putuskan'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CARA KERJA', style: AppTheme.monoLabel),
                      const SizedBox(height: 8),
                      const Text(
                        'App subscribe ke telemetry topic di broker MQTT dan '
                        'menampilkan data device asli (device.telemetry.v1) tanpa '
                        'simulasi. Firmware publish JSON ke topic yang sama. '
                        'Putuskan untuk kembali ke mode simulator.',
                        style: TextStyle(
                            color: AppTheme.muted, fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'command topic: ${sim.commandTopic}',
                        style: AppTheme.monoLabel.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ack topic: ${sim.ackTopic}',
                        style: AppTheme.monoLabel.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'target firmware ${FirmwareConstants.firmwareVersion} · '
                        '${FirmwareConstants.deviceId}',
                        style: AppTheme.monoLabel.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('ACTIVITY LOG', style: AppTheme.monoLabel),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: sim.logs.isEmpty
                      ? const Text('Belum ada aktivitas',
                          style:
                              TextStyle(color: AppTheme.faint, fontSize: 12))
                      : Column(
                          children:
                              sim.logs.take(20).map(_logRow).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
