import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';

/// Small monospace eyebrow label, e.g. "LIVE TELEMETRY".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(), style: AppTheme.monoLabel),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A number that smoothly counts to its latest value between telemetry ticks.
/// Honors reduced-motion (snaps instantly when requested).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.fractionDigits = 0,
    this.unit,
    this.unitStyle,
  });

  final double value;
  final TextStyle style;
  final int fractionDigits;
  final String? unit;
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: AppTheme.motion(context, const Duration(milliseconds: 600)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return RichText(
          text: TextSpan(
            text: v.toStringAsFixed(fractionDigits),
            style: style,
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style:
                      unitStyle ??
                      const TextStyle(
                        fontFamily: AppTheme.fontMono,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.faint,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Press-to-scale wrapper that adds tactile feedback to any tappable element.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppTheme.motion(context, const Duration(milliseconds: 110)),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Pill showing a status word with a leading dot (ok/standby/fault, live, etc).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTheme.motion(context, const Duration(milliseconds: 350)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulse: pulse),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: AppTheme.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, this.pulse = false});
  final Color color;
  final bool pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  void _sync() {
    final reduced = AppTheme.reducedMotion(context);
    if (widget.pulse && !reduced && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if ((!widget.pulse || reduced) && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
    );
    if (!widget.pulse || AppTheme.reducedMotion(context)) return dot;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: dot,
    );
  }
}

/// Compact metric: animated mono value + unit with a small sans label.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    this.value,
    this.valueText,
    this.unit,
    this.fractionDigits = 0,
    this.color,
    this.icon,
    this.flag,
  }) : assert(value != null || valueText != null);

  final String label;
  final double? value;
  final String? valueText;
  final String? unit;
  final int fractionDigits;
  final Color? color;
  final IconData? icon;
  final String? flag; // short textual qualifier, e.g. "HIGH" (color-not-only)

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.ink;
    final numStyle = TextStyle(
      fontFamily: AppTheme.fontMono,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: c,
      height: 1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        border: Border.all(
          color: flag != null ? c.withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: AppTheme.faint),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTheme.monoLabel.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (flag != null)
                Text(
                  flag!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontMono,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valueText != null
                ? Text(valueText!, style: numStyle)
                : AnimatedNumber(
                    value: value!,
                    fractionDigits: fractionDigits,
                    unit: unit,
                    style: numStyle,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Three-quarter (270°) lux gauge with ticks, a target notch and a glowing
/// value tip. Scaled with headroom so "at setpoint" is a visible position.
class LuxGauge extends StatelessWidget {
  const LuxGauge({
    super.key,
    required this.lux,
    required this.targetLux,
    required this.color,
  });

  final double lux;
  final double targetLux;
  final Color color;

  static const double _height = 178;

  @override
  Widget build(BuildContext context) {
    final maxScale = math.max(
      math.max(targetLux * 1.5, lux * 1.1),
      600.0,
    );
    final fill = (lux / maxScale).clamp(0.0, 1.0);
    final targetFrac = (targetLux / maxScale).clamp(0.0, 1.0);
    final atSetpoint = targetLux > 0 && (lux - targetLux).abs() / targetLux < 0.04;

    return Semantics(
      label:
          'Lux saat ini ${lux.toStringAsFixed(0)} dari target '
          '${targetLux.toStringAsFixed(0)}',
      value: atSetpoint ? 'pada setpoint' : null,
      child: RepaintBoundary(
        child: SizedBox(
          height: _height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: fill),
                  duration: AppTheme.motion(
                    context,
                    const Duration(milliseconds: 700),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, p, _) => CustomPaint(
                    painter: _GaugePainter(
                      fill: p,
                      targetFrac: targetFrac,
                      color: color,
                      atSetpoint: atSetpoint,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.08),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedNumber(
                      value: lux,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontMono,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      atSetpoint
                          ? 'LUX · ON SETPOINT'
                          : 'LUX · TARGET ${targetLux.toStringAsFixed(0)}',
                      style: AppTheme.monoLabel.copyWith(
                        fontSize: 10,
                        color: atSetpoint ? color : AppTheme.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fill,
    required this.targetFrac,
    required this.color,
    required this.atSetpoint,
  });
  final double fill;
  final double targetFrac;
  final Color color;
  final bool atSetpoint;

  static const double _start = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 14.0;
    final r = ((size.height - pad * 2) / 1.707).clamp(20.0, size.width / 2 - pad);
    final center = Offset(size.width / 2, pad + r);
    final rect = Rect.fromCircle(center: center, radius: r);

    // Tick marks (minor every step, major every 5).
    const ticks = 30;
    for (var i = 0; i <= ticks; i++) {
      final a = _start + _sweep * (i / ticks);
      final major = i % 5 == 0;
      final inner = r - (major ? 18 : 12);
      final p1 = Offset(center.dx + inner * math.cos(a), center.dy + inner * math.sin(a));
      final p2 = Offset(center.dx + (r - 4) * math.cos(a), center.dy + (r - 4) * math.sin(a));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = (major ? AppTheme.faint : AppTheme.hairline).withValues(
            alpha: major ? 0.55 : 0.3,
          )
          ..strokeWidth = major ? 2 : 1,
      );
    }

    // Track.
    final track = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, track);

    // Progress arc.
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: _start,
        endAngle: _start + _sweep,
        colors: [color.withValues(alpha: 0.45), color],
        transform: const GradientRotation(_start),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * fill, false, arc);

    // Target notch.
    final ta = _start + _sweep * targetFrac;
    final n1 = Offset(center.dx + (r - 10) * math.cos(ta), center.dy + (r - 10) * math.sin(ta));
    final n2 = Offset(center.dx + (r + 8) * math.cos(ta), center.dy + (r + 8) * math.sin(ta));
    canvas.drawLine(
      n1,
      n2,
      Paint()
        ..color = atSetpoint ? color : AppTheme.muted
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Glowing value tip.
    if (fill > 0.02) {
      final ang = _start + _sweep * fill;
      final tip = Offset(center.dx + r * math.cos(ang), center.dy + r * math.sin(ang));
      canvas.drawCircle(
        tip,
        6,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(tip, 4.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fill != fill ||
      old.targetFrac != targetFrac ||
      old.color != color ||
      old.atSetpoint != atSetpoint;
}

/// Sparkline with a baseline grid and a leading value label.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 56,
    this.unit = '',
  });

  final List<double> values;
  final Color color;
  final double height;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparkPainter(values: values, color: color, unit: unit),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, this.unit = ''});
  final List<double> values;
  final Color color;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    // Baseline grid (3 faint horizontal lines).
    final grid = Paint()
      ..color = AppTheme.hairline.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset pt(int i) => Offset(
      i * dx,
      size.height - ((values[i] - minV) / span) * (size.height - 8) - 4,
    );

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Leading dot + value pill.
    final last = pt(values.length - 1);
    canvas.drawCircle(last, 3.5, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: '${values.last.toStringAsFixed(0)}$unit',
        style: TextStyle(
          fontFamily: AppTheme.fontMono,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (last.dx - tp.width - 8).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(lx, (last.dy - tp.height - 6).clamp(0.0, size.height)));
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values.length != values.length ||
      (values.isNotEmpty && old.values.last != values.last) ||
      old.color != color;
}

/// Rich control-room backdrop: slate gradient base, soft accent glow blooms,
/// a blueprint grid (major/minor) and a corner vignette. Replaces flat fills.
class HudGridBackground extends StatelessWidget {
  const HudGridBackground({super.key, this.spacing = 28});
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _GridPainter(spacing: spacing)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.spacing});
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base vertical gradient (deeper at top, warmer slate lower).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1322), Color(0xFF0F1A2E), Color(0xFF0C1424)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // 2. Soft glow blooms for depth.
    void bloom(Offset c, double r, Color col) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [col, col.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    bloom(Offset(size.width * 0.85, size.height * 0.08), size.width * 0.7,
        AppTheme.accent.withValues(alpha: 0.07));
    bloom(Offset(size.width * 0.1, size.height * 0.92), size.width * 0.65,
        AppTheme.info.withValues(alpha: 0.05));

    // 3. Blueprint grid — minor lines, brighter every 4th (major).
    var i = 0;
    final minor = Paint()
      ..color = AppTheme.hairline.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = AppTheme.hairline.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 4 == 0 ? major : minor);
      i++;
    }
    i = 0;
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 4 == 0 ? major : minor);
      i++;
    }

    // 4. Corner vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.15,
          colors: [Colors.transparent, const Color(0xFF060B16).withValues(alpha: 0.55)],
          stops: const [0.58, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.spacing != spacing;
}
