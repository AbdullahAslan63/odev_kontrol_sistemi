import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odev_takip/core/extensions/extensions.dart';
import 'package:odev_takip/core/utils/app_utils.dart';
import 'package:odev_takip/core/utils/phone_number_helper.dart';
import 'package:odev_takip/features/auth/domain/entities/app_user.dart';
import 'package:odev_takip/features/auth/presentation/providers/auth_providers.dart';
import 'package:odev_takip/features/auth/presentation/screens/login_screen.dart';
import 'package:odev_takip/features/auth/presentation/screens/parent_register_screen.dart';
import 'package:odev_takip/features/students/data/models/invite_code_model.dart';
import 'package:odev_takip/features/students/domain/entities/student_entity.dart';

void main() {
  group('InviteCodeModel & Extensions Tests', () {
    test(
        'InviteCodeModel studentName, classId ve className alanlarını serileştirir',
        () {
      final now = DateTime(2026, 11, 22, 12, 0);
      final expiry = now.add(const Duration(days: 14));
      final model = InviteCodeModel(
        code: 'OT-A7K9M2',
        studentId: 'stu-1',
        teacherId: 'tch-1',
        studentName: 'Ali Demir',
        classId: 'cls-8a',
        className: '8-A',
        expiresAt: expiry,
        createdAt: now,
      );

      final map = model.toFirestore();
      expect(map['studentId'], 'stu-1');
      expect(map['teacherId'], 'tch-1');
      expect(map['studentName'], 'Ali Demir');
      expect(map['classId'], 'cls-8a');
      expect(map['className'], '8-A');

      final parsed = InviteCodeModel.fromMap(map, 'OT-A7K9M2');
      expect(parsed.code, 'OT-A7K9M2');
      expect(parsed.studentName, 'Ali Demir');
      expect(parsed.classId, 'cls-8a');
      expect(parsed.className, '8-A');
      expect(parsed.used, false);
    });

    test(
        'InviteCodeGenerator kriptografik OT-XXXXXX formatı üretir ve regex ile eşleşir',
        () {
      final generated = InviteCodeGenerator.generate();
      expect(generated.startsWith('OT-'), true);
      expect(generated.length, 9);
      expect(generated.isValidInviteCode, true);
      expect('ot-a7k9m2'.isValidInviteCode, true);
      expect('INVALID'.isValidInviteCode, false);
    });

    test('StudentEntity opsiyonel className alanını taşır', () {
      final student = StudentEntity(
        id: 's1',
        classId: 'c1',
        className: '7-B',
        teacherId: 't1',
        name: 'Zeynep Kaya',
        createdAt: DateTime(2026, 11, 22),
      );
      expect(student.className, '7-B');
      expect(student.copyWith(className: '8-B').className, '8-B');
    });
  });

  group('PhoneNumberHelper & Auth Session Tests', () {
    test('PhoneNumberHelper Türkiye numaralarını E.164 biçimine dönüştürür',
        () {
      expect(
        PhoneNumberHelper.normalizeToE164('05315635049'),
        '+905315635049',
      );
      expect(
        PhoneNumberHelper.normalizeToE164('531 563 50 49'),
        '+905315635049',
      );
      expect(PhoneNumberHelper.isValidTurkishMobile('05321234567'), isTrue);
      expect(PhoneNumberHelper.isValidTurkishMobile('12345'), isFalse);
      expect(
        PhoneNumberHelper.maskPhoneNumber('+905315635049'),
        '+90 531 *** ** 49',
      );
    });

    test(
        'currentUserProvider stream beklenmeden activeSessionUserProvider değerini döner',
        () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider), isNull);

      final testUser = AppUser(
        uid: 'uid-1',
        role: 'parent',
        name: 'Test Veli',
        email: '',
        phone: '+905321234567',
        createdAt: DateTime(2026, 11, 22),
        updatedAt: DateTime(2026, 11, 22),
      );

      container.read(activeSessionUserProvider.notifier).state = testUser;
      final resolved = container.read(currentUserProvider);
      expect(resolved, isNotNull);
      expect(resolved!.uid, 'uid-1');
      expect(resolved.isParent, isTrue);
    });
  });

  group('Store Readiness Auth UI Tests', () {
    testWidgets(
        'LoginScreen öğretmen için e-posta/şifre, veli için telefon/SMS sunar ve test verisi içermez',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Eduly'), findsOneWidget);
      expect(find.text('E-posta'), findsOneWidget);
      expect(find.text('Şifre'), findsOneWidget);
      expect(find.text('Öğretmen Girişi Yap'), findsOneWidget);
      expect(find.textContaining('123456'), findsNothing);
      expect(find.textContaining('0531'), findsNothing);
      expect(find.textContaining('Sabit Test Kodu'), findsNothing);
      expect(find.textContaining('MatPusula'), findsNothing);

      await tester.tap(find.text('Veli'));
      await tester.pumpAndSettle();

      expect(find.text('Telefon Numarası'), findsOneWidget);
      expect(find.text('SMS Doğrulama Kodu Gönder'), findsOneWidget);
      expect(find.textContaining('123456'), findsNothing);
      expect(find.textContaining('0531'), findsNothing);
      expect(find.textContaining('Sabit Test Kodu'), findsNothing);
      expect(find.textContaining('MatPusula'), findsNothing);
    });

    testWidgets(
        'ParentRegisterScreen test modu içermez ve varsayılan onay kutusu işaretsizdir',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: ParentRegisterScreen(),
          ),
        ),
      );

      expect(find.text('1. Öğrenci Davet Kodu'), findsOneWidget);
      expect(find.textContaining('123456'), findsNothing);
      expect(find.textContaining('0531'), findsNothing);
      expect(find.textContaining('Test Modu'), findsNothing);
    });
  });

  group('Release Hygiene & Config Tests', () {
    test('legacy MatPusula görselleri silinmiş ve Eduly ikonu mevcut olmalıdır',
        () {
      expect(File('assets/images/eduly_app_icon_1024.png').existsSync(), isTrue);
      expect(File('assets/images/matpusula_app_showcase.png').existsSync(),
          isFalse);
      expect(File('assets/images/matpusula_logo.png').existsSync(), isFalse);
      expect(File('assets/images/matpusula_real_screenshots.png').existsSync(),
          isFalse);
    });

    test('codemagic.yaml tag tetikleme ve güvenli TestFlight ayarlarını içerir',
        () {
      final yaml = File('codemagic.yaml').readAsStringSync();
      expect(yaml, contains('branch_patterns:'));
      expect(yaml, contains('eduly-testflight'));
      expect(yaml, contains('tag_patterns:'));
      expect(yaml, contains('submit_to_testflight: true'));
      expect(yaml, contains('submit_to_app_store: false'));
      expect(yaml, contains('pod install || pod install --repo-update'));
    });

    test('Android Gradle dosyaları com.eduly.app ve Crashlytics içerir', () {
      final appGradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      final settingsGradle =
          File('android/settings.gradle.kts').readAsStringSync();
      expect(appGradle, contains('com.eduly.app'));
      expect(appGradle, contains('com.google.firebase.crashlytics'));
      expect(settingsGradle, contains('com.google.firebase.crashlytics'));
    });

    test('firestore.rules ve Windows yayın scriptleri mevcuttur', () {
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules, contains('existingParents'));
      expect(rules, contains('lastInviteCode'));
      expect(File('scripts/build_android_release.ps1').existsSync(), isTrue);
      expect(File('scripts/trigger_ios_release.ps1').existsSync(), isTrue);
    });

    test('iOS sürüm, gizlilik ve Codemagic ayarları tutarlıdır', () {
      final releaseXcconfig =
          File('ios/Flutter/Release.xcconfig').readAsStringSync();
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final googlePlist =
          File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
      final privacyManifest =
          File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
      final pbxproj =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      expect(releaseXcconfig, contains('Pods-Runner.release.xcconfig'));
      expect(releaseXcconfig, contains('Generated.xcconfig'));
      expect(infoPlist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
      expect(infoPlist, contains('<string>Eduly</string>'));
      expect(infoPlist, contains('app-1-763956808451-ios-4e89567e4767231240b736'));
      expect(infoPlist, isNot(contains('NSCameraUsageDescription')));
      expect(infoPlist, isNot(contains('NSMicrophoneUsageDescription')));
      expect(googlePlist, contains('com.eduly.mobile'));
      expect(googlePlist, contains('eduly-server'));
      expect(privacyManifest, contains('NSPrivacyCollectedDataTypeCrashData'));
      expect(privacyManifest, contains('NSPrivacyCollectedDataTypePhoneNumber'));
      expect(
        pbxproj,
        matches(RegExp(r'TARGETED_DEVICE_FAMILY\s*=\s*"?1"?\s*;')),
      );
      expect(
        pbxproj,
        isNot(matches(RegExp(r'TARGETED_DEVICE_FAMILY\s*=\s*"?1,2"?\s*;'))),
      );
      expect(pbxproj, contains('com.eduly.mobile'));
      expect(
        pbxproj,
        isNot(contains(
            'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;')),
      );
    });
  });
}
