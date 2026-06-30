import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/models/telemetry.dart';
import 'package:saqelar/services/device_scope.dart';
import 'package:saqelar/services/sfx.dart';
import 'package:saqelar/widgets/hud_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final sim = DeviceScope.of(context);
    _url = TextEditingController(text: sim.deviceUrl ?? 'http://saqelar.local');
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
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
                // Status
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: live
                            ? 'DEVICE'
                            : (sim.isSimulated ? 'SIM' : 'OFFLINE'),
                        color: color,
                        pulse: live,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Text('ESP32 BASE URL', style: AppTheme.monoLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontMono,
                    color: AppTheme.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.50',
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () {
                            Sfx.instance.success();
                            sim.connect(_url.text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menyambung ke device…'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.wifi_tethering_rounded),
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
                        'Saat URL diisi & terjangkau, app polling '
                        'GET <url>/telemetry tiap 1 detik dan menampilkan data '
                        'device asli (kontrak device.telemetry.v1) — tanpa '
                        'simulasi. Kosongkan / Putuskan untuk kembali ke mode '
                        'simulator.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Target firmware: ${FirmwareConstants.firmwareVersion} · '
                        '${FirmwareConstants.deviceId}',
                        style: AppTheme.monoLabel.copyWith(fontSize: 10),
                      ),
                    ],
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
