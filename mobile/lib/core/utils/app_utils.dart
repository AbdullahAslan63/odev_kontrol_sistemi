import 'dart:math';

/// Net hesaplama yardımcısı.
/// Türkiye'deki 4 yanlış 1 doğruyu götürür sistemi baz alınmıştır.
class NetCalculator {
  NetCalculator._();

  /// Net hesapla
  /// [correct] - Doğru sayısı
  /// [wrong] - Yanlış sayısı
  /// [wrongPenalty] - Yanlış cezası (varsayılan 4)
  static double calculate(int correct, int wrong, {double wrongPenalty = 4.0}) {
    if (correct < 0 || wrong < 0) {
      throw ArgumentError('Doğru ve yanlış sayısı negatif olamaz.');
    }
    return correct - (wrong / wrongPenalty);
  }

  /// Toplam soru sayısını aş kontrolü
  static bool isValid({
    required int correct,
    required int wrong,
    required int blank,
    required int totalQuestions,
  }) {
    return (correct + wrong + blank) <= totalQuestions &&
        correct >= 0 &&
        wrong >= 0 &&
        blank >= 0;
  }

  /// Başarı yüzdesini hesapla
  static double successPercentage(int correct, int totalQuestions) {
    if (totalQuestions == 0) return 0;
    return (correct / totalQuestions) * 100;
  }
}

/// Ödev durum hesaplayıcı
class HomeworkStatusCalculator {
  HomeworkStatusCalculator._();

  /// Ödev durumunu hesapla
  /// status: veritabanındaki durum (pending, completed, missed)
  /// dueDate: teslim tarihi
  static String calculateDisplayStatus(String status, DateTime dueDate) {
    if (status == 'completed') return 'completed';
    if (status == 'missed') return 'missed';
    if (status == 'pending' && DateTime.now().isAfter(dueDate)) {
      return 'overdue';
    }
    return 'pending';
  }

  /// Durum rengi (hex string yerine durum adı döner)
  static String statusLabel(String status) {
    return switch (status) {
      'completed' => 'Tamamlandı',
      'missed' => 'Yapılmadı',
      'overdue' => 'Gecikti',
      _ => 'Bekliyor',
    };
  }
}

/// Sınıf davet kodu: `OT-` + 6 karakter.
/// 0, 1, I ve O yok; okunurken karışmasınlar.
class InviteCodeGenerator {
  InviteCodeGenerator._();

  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const example = 'OT-A7K9M2';

  static final RegExp pattern = RegExp('^OT-[$alphabet]{6}\$');

  static String generate([Random? random]) {
    final rng = random ?? Random();
    final body = List.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return 'OT-$body';
  }

  static bool isValid(String raw) => pattern.hasMatch(raw.trim().toUpperCase());
}
