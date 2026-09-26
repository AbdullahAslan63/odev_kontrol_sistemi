import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_sizes.dart';
import 'app_text_styles.dart';

/// Uygulama tema tanımları.
/// Öğretmen ve Veli için ayrı renk varyantları içerir.
class AppTheme {
  AppTheme._();

  /// Öğretmen teması (lacivert-mavi)
  static ThemeData teacherTheme({Brightness brightness = Brightness.light}) {
    final palette = AppPalette.forBrightness(brightness);
    return _buildTheme(
      seedColor: AppColors.teacherPrimary,
      primaryColor: AppColors.teacherPrimary,
      primarySurface: palette.teacherSurface,
      brightness: brightness,
      palette: palette,
    );
  }

  /// Veli teması (yeşil)
  static ThemeData parentTheme({Brightness brightness = Brightness.light}) {
    final palette = AppPalette.forBrightness(brightness);
    return _buildTheme(
      seedColor: AppColors.parentPrimary,
      primaryColor: AppColors.parentPrimary,
      primarySurface: palette.parentSurface,
      brightness: brightness,
      palette: palette,
    );
  }

  /// Sistem açıkken kullanılan tema (öğretmen varsayılan).
  static ThemeData get light => teacherTheme();

  /// Sistem koyuyken kullanılan tema.
  static ThemeData get dark =>
      teacherTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({
    required Color seedColor,
    required Color primaryColor,
    required Color primarySurface,
    required Brightness brightness,
    required AppPalette palette,
  }) {
    TextStyle tone(TextStyle style, Color color) => style.copyWith(color: color);

    // Tek kaynak: AppTextStyles → ThemeData.textTheme
    final textTheme = TextTheme(
      displayLarge: tone(AppTextStyles.h1, palette.textPrimary),
      displayMedium: tone(AppTextStyles.h2, palette.textPrimary),
      displaySmall: tone(AppTextStyles.h3, palette.textPrimary),
      headlineLarge: tone(AppTextStyles.h1, palette.textPrimary),
      headlineMedium: tone(AppTextStyles.h2, palette.textPrimary),
      headlineSmall: tone(AppTextStyles.h3, palette.textPrimary),
      titleLarge: tone(AppTextStyles.h3, palette.textPrimary),
      titleMedium: tone(AppTextStyles.h4, palette.textPrimary),
      titleSmall: tone(AppTextStyles.labelLarge, palette.textPrimary),
      bodyLarge: tone(AppTextStyles.bodyLarge, palette.textPrimary),
      bodyMedium: tone(AppTextStyles.bodyMedium, palette.textSecondary),
      bodySmall: tone(AppTextStyles.bodySmall, palette.textSecondary),
      labelLarge: tone(AppTextStyles.buttonMedium, AppColors.textOnPrimary),
      labelMedium: tone(AppTextStyles.labelMedium, palette.textSecondary),
      labelSmall: tone(AppTextStyles.labelSmall, palette.textTertiary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        primary: primaryColor,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.accent,
        error: AppColors.error,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
      ),

      // ── Scaffold ──────────────────────────────────────────────────────────
      scaffoldBackgroundColor: palette.background,

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: palette.shadow,
        centerTitle: false,
        titleTextStyle: tone(AppTextStyles.h3, palette.textPrimary)
            .copyWith(fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(
          color: palette.textPrimary,
          size: AppSizes.iconMd,
        ),
      ),

      // ── Bottom Navigation ──────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: primarySurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: primaryColor,
            );
          }
          return AppTextStyles.labelSmall.copyWith(
            color: palette.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: AppSizes.iconMd);
          }
          return IconThemeData(
            color: palette.textSecondary,
            size: AppSizes.iconMd,
          );
        }),
        elevation: 0,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        height: AppSizes.bottomNavHeight,
      ),

      // ── ElevatedButton ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize:
              const Size(double.infinity, AppSizes.primaryButtonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
          elevation: 0,
          textStyle: AppTextStyles.buttonLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize:
              const Size(double.infinity, AppSizes.primaryButtonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
          side: BorderSide(color: primaryColor, width: 1.5),
          textStyle: AppTextStyles.buttonLarge.copyWith(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, AppSizes.minimumTouchTarget),
          textStyle: AppTextStyles.labelLarge.copyWith(color: primaryColor),
        ),
      ),

      // ── Input ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: tone(AppTextStyles.inputHint, palette.textTertiary),
        labelStyle: tone(AppTextStyles.inputLabel, palette.textSecondary),
        errorStyle: AppTextStyles.inputError,
      ),

      // ── Card ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: palette.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 0,
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceVariant,
        selectedColor: primarySurface,
        labelStyle: tone(AppTextStyles.labelMedium, palette.textSecondary),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.chipRadius),
        ),
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? AppPalette.light.surface
            : AppPalette.light.textPrimary,
        contentTextStyle: AppTextStyles.bodySmall.copyWith(
          color: brightness == Brightness.dark
              ? AppPalette.light.textPrimary
              : AppColors.textOnPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── Dialog ─────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.dialogRadius),
        ),
        titleTextStyle: tone(AppTextStyles.h3, palette.textPrimary)
            .copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: tone(AppTextStyles.bodyMedium, palette.textSecondary),
        elevation: 8,
      ),

      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: AppColors.textOnPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),

      // ── ListTile ───────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        minLeadingWidth: 0,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
        tileColor: Colors.transparent,
        titleTextStyle: tone(AppTextStyles.h4, palette.textPrimary),
        subtitleTextStyle: tone(AppTextStyles.bodySmall, palette.textSecondary),
        iconColor: palette.textSecondary,
      ),

      // ── Switch ─────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return palette.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primarySurface;
          return palette.border;
        }),
      ),

      // ── ProgressIndicator ──────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primarySurface,
        circularTrackColor: primarySurface,
      ),
    );
  }
}
