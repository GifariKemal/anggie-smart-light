import 'package:flutter/material.dart';

/// Dark industrial "control-room" theme for Saqelar IoT.
///
/// Single status accent (green) doubles as the firmware `safetyState=ok` /
/// live / relay-ON signal. Amber = standby, red = fault. Numerics use FiraMono
/// (tabular HUD feel); labels/headings use FiraSans.
class AppTheme {
  // Surfaces (deep slate / OLED-friendly)
  static const Color bg = Color(0xFF0F172A); // background
  static const Color surface = Color(0xFF1E293B); // cards
  static const Color surfaceAlt = Color(0xFF172033); // inset panels
  static const Color border = Color(0xFF2B3A52);
  static const Color borderStrong = Color(0xFF475569);

  // Text
  static const Color ink = Color(0xFFF8FAFC); // primary text
  static const Color muted = Color(0xFF94A3B8); // secondary text
  static const Color faint = Color(0xFF9AA8BE); // captions — lifted to pass AA
  static const Color hairline = Color(0xFF64748B); // decorative lines only

  // Radius scale
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 18;

  // Status accents
  static const Color accent = Color(0xFF22C55E); // ok / live / on (primary)
  static const Color warning = Color(0xFFF59E0B); // standby / syncing
  static const Color danger = Color(0xFFEF4444); // fault
  static const Color info = Color(0xFF38BDF8); // neutral data highlight

  static const String fontSans = 'FiraSans';
  static const String fontMono = 'FiraMono';

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
      error: danger,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF052E16),
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: fontSans,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.4,
          height: 1.1,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.45),
        bodySmall: TextStyle(fontSize: 13, color: muted, height: 1.4),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.6,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      iconTheme: const IconThemeData(color: muted),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF052E16),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Monospace label-style text for HUD numerics (eyebrows / units).
  static const TextStyle monoLabel = TextStyle(
    fontFamily: fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: faint,
  );

  /// Returns [d], or [Duration.zero] when the OS requests reduced motion.
  static Duration motion(BuildContext context, Duration d) {
    return (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? Duration.zero
        : d;
  }

  static bool reducedMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Color for a firmware safetyState value.
  static Color safetyColor(String state) {
    switch (state) {
      case 'fault':
        return danger;
      case 'standby':
        return warning;
      default:
        return accent;
    }
  }
}
