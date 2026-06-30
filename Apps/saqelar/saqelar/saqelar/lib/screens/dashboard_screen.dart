import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/models/telemetry.dart';
import 'package:saqelar/screens/control_screen.dart';
import 'package:saqelar/screens/settings_screen.dart';
import 'package:saqelar/services/device_scope.dart';
import 'package:saqelar/services/sfx.dart';
import 'package:saqelar/widgets/hud_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    // Fault alarm sound, driven by the simulator (never from build()).
    DeviceScope.of(context).onFaultEnter = () {
      if (mounted) Sfx.instance.alert();
    };
    if (AppTheme.reducedMotion(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Widget _item(int i, Widget child) {
    final begin = (i * 0.08).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _reveal,
      curve: Interval(begin, (begin + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = DeviceScope.of(context); // rebuilds on each telemetry tick
    final t = sim.latest;

    return Scaffold(
      body: Stack(
        children: [
          const HudGridBackground(),
          // Fault vignette overlay (declarative — no build side-effects).
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: (t != null && !t.isOk) ? 1 : 0,
              duration: AppTheme.motion(context, const Duration(milliseconds: 500)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      AppTheme.safetyColor(t?.safetyState ?? 'ok')
                          .withValues(alpha: 0.16),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SafeArea(
            child: t == null
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _Header(t: t)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        sliver: SliverList.list(
                          children: [
                            _item(0, _HeroPanel(t: t)),
                            const SizedBox(height: 14),
                            _item(1, _MetricsGrid(t: t)),
                            const SizedBox(height: 14),
                            _item(2,
                                _TrendsPanel(lux: sim.luxHistory, power: sim.powerHistory)),
                            const SizedBox(height: 14),
                            _item(3, _PidPanel(t: t)),
                            const SizedBox(height: 14),
                            _item(4, _SafetyPanel(t: t)),
                            const SizedBox(height: 18),
                            _item(5, const _ControlButton()),
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

String _two(int v) => v.toString().padLeft(2, '0');
String _clock(DateTime d) =>
    '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
String _uptime(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

class _Header extends StatelessWidget {
  const _Header({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    final sim = DeviceScope.of(context);
    final src = sim.isLive ? 'DEVICE' : (sim.isSimulated ? 'SIM' : 'OFFLINE');
    final srcColor = sim.isLive
        ? AppTheme.accent
        : (sim.isSimulated ? AppTheme.info : AppTheme.warning);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.lightbulb_circle_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(FirmwareConstants.deviceName,
                    style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    Text('${t.deviceId} · seq ${t.seq}  ·  ',
                        style: AppTheme.monoLabel.copyWith(fontSize: 10)),
                    Text(src,
                        style: AppTheme.monoLabel
                            .copyWith(fontSize: 10, color: srcColor)),
                  ],
                ),
              ],
            ),
          ),
          StatusBadge(
            label: t.relayOn ? 'LIVE' : 'IDLE',
            color: t.relayOn ? AppTheme.accent : AppTheme.faint,
            pulse: t.relayOn,
          ),
          IconButton(
            tooltip: 'Device connection',
            onPressed: () {
              Sfx.instance.tap();
              Navigator.push(context, _slideFadeRoute(const SettingsScreen()));
            },
            icon: const Icon(Icons.settings_rounded, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    final safety = AppTheme.safetyColor(t.safetyState);
    return AnimatedContainer(
      duration: AppTheme.motion(context, const Duration(milliseconds: 400)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surface, AppTheme.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        border: Border.all(
            color: t.isOk ? AppTheme.border : safety.withValues(alpha: 0.6)),
        boxShadow: t.isOk
            ? null
            : [
                BoxShadow(
                    color: safety.withValues(alpha: 0.22),
                    blurRadius: 26,
                    spreadRadius: -6),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('LIGHTING OUTPUT', style: AppTheme.monoLabel),
              const Spacer(),
              StatusBadge(
                  label: t.safetyState.toUpperCase(),
                  color: safety,
                  pulse: !t.isOk),
            ],
          ),
          const SizedBox(height: 6),
          LuxGauge(lux: t.lux, targetLux: t.targetLux, color: safety),
          const SizedBox(height: 16),
          _DimmerBar(dimmer: t.dimmerPct, color: safety, on: t.relayOn),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Relay',
                  value: t.relayOn ? 'ON' : 'OFF',
                  color: t.relayOn ? AppTheme.accent : AppTheme.faint,
                ),
              ),
              _vline(),
              Expanded(child: _MiniStat(label: 'Mode', value: t.mode.toUpperCase())),
              _vline(),
              Expanded(child: _MiniStat(label: 'Clock', value: _clock(t.timestamp))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vline() => Container(width: 1, height: 30, color: AppTheme.border);
}

class _DimmerBar extends StatefulWidget {
  const _DimmerBar({required this.dimmer, required this.color, required this.on});
  final int dimmer;
  final Color color;
  final bool on;

  @override
  State<_DimmerBar> createState() => _DimmerBarState();
}

class _DimmerBarState extends State<_DimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  void _sync() {
    final run = widget.on && !AppTheme.reducedMotion(context);
    if (run && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!run && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_DimmerBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('DIMMER', style: AppTheme.monoLabel.copyWith(fontSize: 10)),
            const Spacer(),
            Text(
              '${widget.dimmer}%',
              style: TextStyle(
                fontFamily: AppTheme.fontMono,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.on ? AppTheme.ink : AppTheme.faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 14,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _shimmer,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _DimmerPainter(
                value: (widget.dimmer / FirmwareConstants.dimmerMaxPct)
                    .clamp(0.0, 1.0),
                color: widget.on ? widget.color : AppTheme.faint,
                shimmer: widget.on ? _shimmer.value : -1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimmerPainter extends CustomPainter {
  _DimmerPainter({required this.value, required this.color, required this.shimmer});
  final double value;
  final Color color;
  final double shimmer; // -1 = off

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(rr, Paint()..color = AppTheme.bg);
    final fillW = size.width * value;
    if (fillW > 0) {
      final fr = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillW, size.height),
          Radius.circular(size.height / 2));
      // Soft glow beneath the fill.
      if (shimmer >= 0) {
        canvas.drawRRect(
          fr,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawRRect(fr, Paint()..color = color);
      // Glossy top highlight.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(2, 2, (fillW - 4).clamp(0, fillW), size.height * 0.4),
            Radius.circular(size.height / 2)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
      // Energized shimmer sweeping across the filled section.
      if (shimmer >= 0) {
        final cx = fillW * shimmer;
        canvas.save();
        canvas.clipRRect(fr);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, size.height / 2), width: 40, height: size.height),
          Paint()
            ..shader = LinearGradient(colors: [
              color.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.45),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCenter(
                center: Offset(cx, size.height / 2),
                width: 40,
                height: size.height)),
        );
        canvas.restore();
      }
    }
    // 10% tick marks.
    final tick = Paint()
      ..color = AppTheme.bg
      ..strokeWidth = 1.5;
    for (var i = 1; i < 10; i++) {
      final x = size.width * (i / 10);
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), tick);
    }
  }

  @override
  bool shouldRepaint(_DimmerPainter old) =>
      old.value != value || old.color != color || old.shimmer != shimmer;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: AppTheme.monoLabel.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontMono,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? AppTheme.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    final overCurrent = t.currentMa > FirmwareConstants.maxSafeCurrentMa * 0.85;
    final daylight = t.ldrRaw > FirmwareConstants.ldrDaylightRaw;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.95,
      children: [
        MetricTile(
          label: 'Current',
          value: t.currentMa,
          unit: 'mA',
          icon: Icons.bolt_rounded,
          color: overCurrent ? AppTheme.warning : AppTheme.ink,
          flag: overCurrent ? 'HIGH' : null,
        ),
        MetricTile(
          label: 'Power',
          value: t.powerW,
          fractionDigits: 1,
          unit: 'W',
          icon: Icons.electric_meter_rounded,
        ),
        MetricTile(
          label: 'Ambient (LDR)',
          value: t.ldrRaw.toDouble(),
          unit: 'raw',
          icon: Icons.wb_sunny_rounded,
          color: daylight ? AppTheme.warning : AppTheme.ink,
          flag: daylight ? 'DAY' : null,
        ),
        MetricTile(
          label: 'Uptime',
          valueText: _uptime(t.uptime),
          icon: Icons.schedule_rounded,
        ),
      ],
    );
  }
}

class _TrendsPanel extends StatelessWidget {
  const _TrendsPanel({required this.lux, required this.power});
  final List<double> lux;
  final List<double> power;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'Trend · last ${lux.length} samples',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text('Lux', style: AppTheme.monoLabel.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Sparkline(values: lux, color: AppTheme.accent),
          const SizedBox(height: 14),
          Text('Power (W)', style: AppTheme.monoLabel.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Sparkline(values: power, color: AppTheme.info, unit: 'W'),
        ],
      ),
    );
  }
}

class _PidPanel extends StatelessWidget {
  const _PidPanel({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'PID controller',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            _pid('Kp', t.kp),
            _pid('Ki', t.ki),
            _pid('Kd', t.kd),
            _pid('Out', t.pidOutput, highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _pid(String k, double v, {bool highlight = false}) => Expanded(
        child: Column(
          children: [
            Text(k.toUpperCase(), style: AppTheme.monoLabel.copyWith(fontSize: 10)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                v.toStringAsFixed(2),
                style: TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppTheme.accent : AppTheme.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({required this.t});
  final Telemetry t;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.safetyColor(t.safetyState);
    return _Panel(
      label: 'Safety guard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                t.isFault
                    ? Icons.gpp_maybe_rounded
                    : t.isStandby
                        ? Icons.nightlight_round
                        : Icons.verified_user_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.faultReason ?? 'All readings within safe limits',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _limit(
            'Max current',
            '${FirmwareConstants.maxSafeCurrentMa.toStringAsFixed(0)} mA',
            t.currentMa / FirmwareConstants.maxSafeCurrentMa,
            AppTheme.danger,
          ),
          const SizedBox(height: 8),
          _limit(
            'Daylight cutoff',
            '${FirmwareConstants.ldrDaylightRaw} raw',
            t.ldrRaw / FirmwareConstants.ldrDaylightRaw,
            AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _limit(String label, String cap, double ratio, Color color) {
    final r = ratio.clamp(0.0, 1.0);
    final pct = (r * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const Spacer(),
            Text('$pct% · $cap', style: AppTheme.monoLabel.copyWith(fontSize: 10)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: r,
            minHeight: 5,
            backgroundColor: AppTheme.bg,
            color: r > 0.85 ? color : AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), child],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: () {
          Sfx.instance.tap();
          Navigator.push(context, _slideFadeRoute(const ControlScreen()));
        },
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Open control panel'),
      ),
    );
  }
}

Route<T> _slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}
