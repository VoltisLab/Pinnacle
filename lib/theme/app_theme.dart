import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm parchment light theme; deep, calm surfaces at night.
abstract final class AppTheme {
  /// Warm parchment — page background and tonal button labels (light mode).
  static const Color lightCreamCanvas = Color(0xFFF1E8DE);
  static const Color lightCreamMid = Color(0xFFE6D9CC);
  /// Filled “tan” controls on the cream canvas (Send screen, etc.).
  static const Color lightWarmTan = Color(0xFFC9A86C);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          surfaceTint: Colors.transparent,
          primary: Color(0xFF3A302B),
          onPrimary: Color(0xFFFDF9F4),
          primaryContainer: Color(0xFFE5D6CA),
          onPrimaryContainer: Color(0xFF261F1B),
          secondary: Color(0xFF4A5A4E),
          onSecondary: Color(0xFFFDF9F4),
          secondaryContainer: Color(0xFFD6E0D8),
          onSecondaryContainer: Color(0xFF1A221C),
          tertiary: Color(0xFF5C4A3D),
          onTertiary: Color(0xFFFDF9F4),
          tertiaryContainer: Color(0xFFE8DDD4),
          onTertiaryContainer: Color(0xFF2A221C),
          error: Color(0xFFB91C1C),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFBF7F1),
          onSurface: Color(0xFF1F1814),
          onSurfaceVariant: Color(0xFF5A524C),
          surfaceContainerHighest: Color(0xFFEDE5DD),
          outline: Color(0xFFBEB0A5),
          outlineVariant: Color(0xFFD9CFC4),
          shadow: Color(0x1A0F172A),
          scrim: Color(0x660F172A),
          inverseSurface: Color(0xFF2A2622),
          onInverseSurface: Color(0xFFF5F0EA),
          inversePrimary: Color(0xFFC9A86C),
        ),
        scaffold: lightCreamCanvas,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          surfaceTint: Colors.transparent,
          primary: Color(0xFF60A5FA),
          onPrimary: Color(0xFF0B1220),
          primaryContainer: Color(0xFF1E3A8A),
          onPrimaryContainer: Color(0xFFBFDBFE),
          secondary: Color(0xFF38BDF8),
          onSecondary: Color(0xFF0B1220),
          secondaryContainer: Color(0xFF0C4A6E),
          onSecondaryContainer: Color(0xFFE0F2FE),
          tertiary: Color(0xFF818CF8),
          onTertiary: Color(0xFF0B1220),
          error: Color(0xFFF87171),
          onError: Color(0xFF450A0A),
          surface: Color(0xFF151F2E),
          onSurface: Color(0xFFF1F5F9),
          onSurfaceVariant: Color(0xFF94A3B8),
          surfaceContainerHighest: Color(0xFF1E293B),
          outline: Color(0xFF334155),
          outlineVariant: Color(0xFF1E293B),
          shadow: Color(0x66000000),
          scrim: Color(0x99000000),
          inverseSurface: Color(0xFFF1F5F9),
          onInverseSurface: Color(0xFF0F172A),
          inversePrimary: Color(0xFF1D4ED8),
        ),
        scaffold: const Color(0xFF0B1220),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final isLight = brightness == Brightness.light;
    final border = scheme.outline.withValues(alpha: isLight ? 0.55 : 0.65);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: isLight ? 0.45 : 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isLight ? 0.9 : 0.5),
      ),
    );
  }
}
