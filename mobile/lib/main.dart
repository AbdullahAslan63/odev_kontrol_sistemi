import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/fcm_service.dart';
import 'core/services/sms_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Sistem UI ayarları ────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Yalnızca dikey yönlendirme
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase kısa timeout; FCM/Crashlytics ilk kareyi bekletmesin.
  await _bootstrapFirebase();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

Future<void> _bootstrapFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web)
          .timeout(const Duration(seconds: 8));
    } else {
      await Firebase.initializeApp()
          .timeout(const Duration(seconds: 5));
    }
  } catch (e) {
    debugPrint('Firebase initialize warning: $e');
    return;
  }

  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
    unawaited(SmsService.ensureRecaptchaReady());
  }

  if (!kIsWeb) {
    final crashlyticsEnabled = !kDebugMode;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(crashlyticsEnabled)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Crashlytics init warning: $e');
    }
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (crashlyticsEnabled) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (crashlyticsEnabled) {
        unawaited(
          FirebaseCrashlytics.instance
              .recordError(error, stack, fatal: true),
        );
      }
      return true;
    };
  }

  unawaited(FcmService.initialize());
}
