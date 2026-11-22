import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../extensions/extensions.dart';

/// Harici bağlantıları (Gizlilik Politikası, Kullanım Koşulları, Destek E-postası) açar.
class UrlUtils {
  UrlUtils._();

  static Future<void> openUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      if (context.mounted) {
        context.showSnackBar('Bağlantı açılamadı.', isError: true);
      }
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        context.showSnackBar('Bağlantı tarayıcıda açılamadı.', isError: true);
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar('Bağlantı açılırken bir sorun oluştu.', isError: true);
      }
    }
  }

  static Future<void> openSupportEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {'subject': 'Eduly Destek Talebi'},
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        context.showSnackBar(
          'E-posta uygulaması açılamadı. Adres: ${AppConstants.supportEmail}',
        );
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar(
          'Destek e-postası: ${AppConstants.supportEmail}',
        );
      }
    }
  }
}
