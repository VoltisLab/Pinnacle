import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark and light variants that share one accent (warm gold) and the same
/// display typography, so switching themes feels like turning a dimmer
/// rather than changing apps.
abstract final class AppTheme {
  // Shared accent.
  static const Color _gold = Color(0xFFC9A66B);
  static const Color _goldMuted = Color(0xFF9E8B67);

  // Dark palette.
  static const Color _darkInk = Color(0xFF0B0B0D);
  static const Color _darkSurface = Color(0xFF131316);
  static const Color _darkSurfaceHigh = Color(0xFF1C1C21);
  static const Color _darkMist = Color(0xFFE9E6E0);

  // Light palette.
  static const Color _lightPaper = Color(0xFFF7F5F0);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceHigh = Color(0xFFEFEBE2);
  static const Color _lightInk = Color(0xFF1B1A17);

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: _darkInk,
        surface: _darkSurface,
        surfaceHigh: _darkSurfaceHigh,
        foreground: _darkMist,
        outline: const Color(0xFF2E2E35),
        subtleOutline: const Color(0xFF2A2A32),
        strongOutline: const Color(0xFF3A3A44),
        hint: const Color(0xFF7A7670),
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: _lightPaper,
        surface: _lightSurface,
        surfaceHigh: _lightSurfaceHigh,
        foreground: _lightInk,
        outline: const Color(0xFFDED8CA),
        subtleOutline: const Color(0xFFE1DCCF),
        strongOutline: const Color(0xFFC9C2B0),
        hint: const Color(0xFF8D877C),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color foreground,
    required Color outline,
    required Color subtleOutline,
    required Color strongOutline,
    required Color hint,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        surface: surface,
        primary: _gold,
        onPrimary: _darkInk,
        secondary: _goldMuted,
        onSecondary: _darkInk,
        surfaceContainerHighest: surfaceHigh,
        onSurface: foreground,
        outline: outline,
      ),
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: foreground, displayColor: foreground);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: subtleOutline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: foreground.withOpacity(0.85),
        textColor: foreground,
      ),
      dividerTheme: DividerThemeData(
        color: subtleOutline,
        thickness: 0.6,
        space: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: _darkInk,
          backgroundColor: _gold,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: strongOutline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _gold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: hint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _gold : hint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _gold.withOpacity(0.32)
              : outline.withOpacity(0.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
