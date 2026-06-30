import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/widgets/hud_widgets.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _boot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _boot.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigated) return;
    if (AppTheme.reducedMotion(context)) {
      _go();
    } else {
      _boot.forward();
      _glow.repeat(reverse: true);
    }
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const OnboardingScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  void dispose() {
    _boot.dispose();
    _glow.dispose();
    super.dispose();
  }

  String _stage(double p) =>
      p < 0.34 ? 'INIT' : (p < 0.7 ? 'LINK' : 'READY');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          const HudGridBackground(),
          Center(
            child: Semantics(
              label: 'Saqelar IoT sedang dimuat',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (context, child) => Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent
                                .withValues(alpha: 0.18 + 0.22 * _glow.value),
                            blurRadius: 24 + 18 * _glow.value,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: const Icon(Icons.lightbulb_circle_rounded,
                        color: AppTheme.accent, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text('Saqelar IoT',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('CONTROL · MONITORING',
                      style: AppTheme.monoLabel.copyWith(fontSize: 11)),
                  const SizedBox(height: 32),
                  // Determinate boot bar with stage label.
                  SizedBox(
                    width: 180,
                    child: AnimatedBuilder(
                      animation: _boot,
                      builder: (context, _) {
                        final p = _boot.value;
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: p == 0 ? null : p,
                                minHeight: 4,
                                backgroundColor: AppTheme.border,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${_stage(p)} · ${(p * 100).toStringAsFixed(0)}%',
                              style: AppTheme.monoLabel.copyWith(fontSize: 10),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
