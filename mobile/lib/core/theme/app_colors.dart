import 'package:flutter/material.dart';

/// Açık ve koyu yüzey renkleri. Marka renkleri [AppColors] üzerinde sabit kalır.
class AppPalette {
  const AppPalette({
    required this.teacherSurface,
    required this.parentSurface,
    required this.successLight,
    required this.warningLight,
    required this.errorLight,
    required this.infoLight,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.shadow,
  });

  final Color teacherSurface;
  final Color parentSurface;
  final Color successLight;
  final Color warningLight;
  final Color errorLight;
  final Color infoLight;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color shadow;

  static const light = AppPalette(
    teacherSurface: Color(0xFFEEF2FF),
    parentSurface: Color(0xFFF0FDFA),
    successLight: Color(0xFFDCFCE7),
    warningLight: Color(0xFFFEF9C3),
    errorLight: Color(0xFFFEE2E2),
    infoLight: Color(0xFFDBEAFE),
    background: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    divider: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    textDisabled: Color(0xFF64748B),
    shadow: Color(0x1A0F172A),
  );

  static const dark = AppPalette(
    teacherSurface: Color(0xFF1E1B4B),
    parentSurface: Color(0xFF042F2E),
    successLight: Color(0xFF14532D),
    warningLight: Color(0xFF713F12),
    errorLight: Color(0xFF7F1D1D),
    infoLight: Color(0xFF1E3A8A),
    background: Color(0xFF0B1020),
    surface: Color(0xFF151B2E),
    surfaceVariant: Color(0xFF1E293B),
    border: Color(0xFF334155),
    divider: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF94A3B8),
    textDisabled: Color(0xFF64748B),
    shadow: Color(0x66000000),
  );

  /// Cihazın açık/koyu ayarı. MaterialApp her iki temayı da açıkça kurar;
  /// ekranlardaki [AppColors] okumaları bu paleti kullanır.
  static AppPalette get current {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? dark : light;
  }

  static AppPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Uygulamanın renkleri.
/// Nötr yüzey ve metin renkleri sistem temasına göre değişir.
/// Marka ve durum renkleri her iki temada aynıdır.
class AppColors {
  AppColors._();

  // ── Öğretmen & Ana tema renkleri (Eduly Moru & İndigo) ───────────
  static const Color teacherPrimary = Color(0xFF4F46E5);
  static const Color teacherLight = Color(0xFF6366F1);
  static Color get teacherSurface => AppPalette.current.teacherSurface;

  // ── Veli renkleri (Eduly Zümrüt Yeşili) ─────────────────────────
  static const Color parentPrimary = Color(0xFF0D9488);
  static const Color parentLight = Color(0xFF14B8A6);
  static Color get parentSurface => AppPalette.current.parentSurface;

  // ── Vurgu (Eduly Pusula İğnesi Altını) ───────────────────────────
  static const Color accent = Color(0xFFD97706);

  // ── Durum renkleri ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static Color get successLight => AppPalette.current.successLight;
  static const Color warning = Color(0xFFF59E0B);
  static Color get warningLight => AppPalette.current.warningLight;
  static const Color error = Color(0xFFDC2626);
  static Color get errorLight => AppPalette.current.errorLight;
  static const Color info = Color(0xFF2563EB);
  static Color get infoLight => AppPalette.current.infoLight;

  // ── Ödev durum renkleri ───────────────────────────────────────────────────
  static const Color statusPending = Color(0xFFF59E0B); // Bekliyor
  static const Color statusCompleted = Color(0xFF16A34A); // Tamamlandı
  static const Color statusMissed = Color(0xFFDC2626); // Yapılmadı
  static const Color statusOverdue = Color(0xFF991B1B); // Gecikti

  // ── Nötr / zemin ──────────────────────────────────────────────────────────
  static Color get background => AppPalette.current.background;
  static Color get surface => AppPalette.current.surface;
  static Color get surfaceVariant => AppPalette.current.surfaceVariant;
  static Color get border => AppPalette.current.border;
  static Color get divider => AppPalette.current.divider;

  // ── Metin (WCAG AA: normal ≥4.5:1, büyük ≥3:1) ───────────────────────────
  static Color get textPrimary => AppPalette.current.textPrimary;
  static Color get textSecondary => AppPalette.current.textSecondary;
  /// İkincil/caption metin — eski #94A3B8 yerine slate-500 (daha iyi kontrast)
  static Color get textTertiary => AppPalette.current.textTertiary;
  /// Gerçekten pasif / disabled UI (hint, kapalı switch)
  static Color get textDisabled => AppPalette.current.textDisabled;
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  /// Primary/header üzerindeki alt metin (~%90 opaklık)
  static const Color textOnPrimaryMuted = Color(0xE6FFFFFF);

  // ── Gölge ─────────────────────────────────────────────────────────────────
  static Color get shadow => AppPalette.current.shadow;
}
