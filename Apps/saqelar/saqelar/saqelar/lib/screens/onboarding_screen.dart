import 'package:flutter/material.dart';
import 'package:saqelar/screens/dashboard_screen.dart';
import 'package:saqelar/services/sfx.dart';
import 'package:saqelar/widget/dot_indicator.dart';
import 'package:saqelar/widget/onboarding_buttons.dart';
import 'package:saqelar/widget/onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _onboardingData = const [
    _OnboardingSlide(
      icon: Icons.monitor_heart_rounded,
      title: "Monitor lampu real-time",
      description:
          "Lihat status device, lux, dimmer, arus, dan daya dari satu dashboard.",
      badge: "Live monitoring",
    ),
    _OnboardingSlide(
      icon: Icons.tune_rounded,
      title: "Kontrol tetap terkendali",
      description:
          "Command ON/OFF menampilkan proses pending, gagal, atau berhasil dengan jelas.",
      badge: "Control surface",
    ),
    _OnboardingSlide(
      icon: Icons.energy_savings_leaf_rounded,
      title: "Hemat energi dengan aman",
      description:
          "Safety, fault, dan target lux dibuat mudah dipantau sebelum masuk ke device.",
      badge: "Safety first",
    ),
  ];

  void _onNext() {
    if (_currentPage < _onboardingData.length - 1) {
      Sfx.instance.tap();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _enterApp();
    }
  }

  void _onSkip() {
    Sfx.instance.tap();
    _enterApp();
  }

  void _enterApp() {
    Sfx.instance.success();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const DashboardScreen(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  if (!mounted) return;
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final slide = _onboardingData[index];
                  return OnboardingContent(
                    icon: slide.icon,
                    title: slide.title,
                    description: slide.description,
                    badge: slide.badge,
                  );
                },
              ),
            ),
            DotIndicator(
              currentIndex: _currentPage,
              totalDots: _onboardingData.length,
            ),
            OnboardingButtons(
              onSkip: _onSkip,
              onNext: _onNext,
              isLastPage: _currentPage == _onboardingData.length - 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });
}
