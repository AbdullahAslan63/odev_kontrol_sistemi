import 'package:flutter/material.dart';

class _NeutralPalette {
  const _NeutralPalette({
    required this.primarySurface,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color primarySurface;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  static const light = _NeutralPalette(
    primarySurface: Color(0xFFEEF2FF),
    background: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
  );

  static const dark = _NeutralPalette(
    primarySurface: Color(0xFF1E1B4B),
    background: Color(0xFF0B1020),
    surface: Color(0xFF151B2E),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
  );

  static _NeutralPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static _NeutralPalette get current => forBrightness(
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );
}

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF6366F1);
  static Color get primarySurface => _NeutralPalette.current.primarySurface;
  static const Color accent = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static Color get background => _NeutralPalette.current.background;
  static Color get surface => _NeutralPalette.current.surface;
  static Color get border => _NeutralPalette.current.border;
  static Color get textPrimary => _NeutralPalette.current.textPrimary;
  static Color get textSecondary => _NeutralPalette.current.textSecondary;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = _NeutralPalette.forBrightness(brightness);
    const seed = AppColors.primary;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        primary: seed,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
      ),
      scaffoldBackgroundColor: colors.background,
      fontFamily: 'Segoe UI',
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
