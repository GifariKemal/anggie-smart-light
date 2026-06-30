import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';

class DotIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalDots;

  const DotIndicator({
    super.key,
    required this.currentIndex,
    required this.totalDots,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalDots,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: currentIndex == index ? 22.0 : 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color:
                currentIndex == index
                    ? AppTheme.accent
                    : AppTheme.muted.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      ),
    );
  }
}
