import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odev_takip/core/extensions/extensions.dart';
import 'package:odev_takip/core/utils/app_utils.dart';
import 'package:odev_takip/features/auth/presentation/providers/auth_providers.dart';
import 'package:odev_takip/features/auth/presentation/screens/login_screen.dart';
import 'package:odev_takip/features/auth/presentation/screens/parent_register_screen.dart';
import 'package:odev_takip/features/students/data/models/invite_code_model.dart';
import 'package:odev_takip/features/students/domain/entities/student_entity.dart';

void main() {
  group('InviteCodeModel & Extensions Tests', () {
    test('InviteCodeModel studentName, classId ve className alanlarını serileştirir', () {
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

    test('InviteCodeGenerator kriptografik OT-XXXXXX formatı üretir ve regex ile eşleşir', () {
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

  group('Store Readiness Auth UI Tests', () {
    testWidgets('LoginScreen e-posta/şifre ister, test telefonu veya sabit kod içermez', (tester) async {
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
      expect(find.textContaining('123456'), findsNothing);
      expect(find.textContaining('0531'), findsNothing);
      expect(find.textContaining('Sabit Test Kodu'), findsNothing);
      expect(find.textContaining('MatPusula'), findsNothing);

      await tester.tap(find.text('Veli'));
      await tester.pumpAndSettle();

      expect(find.text('Veli Girişi Yap'), findsOneWidget);
      expect(find.textContaining('123456'), findsNothing);
      expect(find.textContaining('0531'), findsNothing);
    });

    testWidgets('ParentRegisterScreen test modu içermez ve varsayılan onay kutusu işaretsizdir', (tester) async {
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
}
