import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';

class OnboardingButtons extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool isLastPage;

  const OnboardingButtons({
    super.key,
    required this.onSkip,
    required this.onNext,
    required this.isLastPage,
  });

  @override
  Widget build(BuildContext context) {
    // Keep CTAs clear of the system gesture bar at the very bottom edge.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Row(
        children: [
          if (!isLastPage)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(foregroundColor: AppTheme.muted),
              child: const Text('Lewati'),
            )
          else
            const SizedBox(width: 82),
          const Spacer(),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              icon: Icon(
                isLastPage
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(isLastPage ? 'Mulai' : 'Lanjut'),
            ),
          ),
        ],
      ),
    );
  }
}
