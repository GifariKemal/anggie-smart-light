import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/services/device_scope.dart';

class OnboardingContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  const OnboardingContent({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 188 : 232,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.surface, AppTheme.surfaceAlt],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: compact ? 62 : 76,
                        height: compact ? 62 : 76,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: AppTheme.accent,
                          size: compact ? 30 : 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TelemetryPreview(compact: compact),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 20 : 30),
                _Badge(label: badge),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: AppTheme.fontMono,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TelemetryPreview extends StatelessWidget {
  final bool compact;

  const _TelemetryPreview({required this.compact});

  @override
  Widget build(BuildContext context) {
    // Live values from the running simulator — sells "real-time" honestly.
    final t = DeviceScope.of(context).latest;
    final rows = [
      ('Lux', t?.lux.toStringAsFixed(0) ?? '426'),
      ('Dimmer', '${t?.dimmerPct ?? 68}%'),
      ('Safety', (t?.safetyState ?? 'ok').toUpperCase()),
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.monoLabel.copyWith(fontSize: 10),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: TextStyle(
                      fontFamily: AppTheme.fontMono,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                      color: row.$1 == 'Safety' ? AppTheme.accent : AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
