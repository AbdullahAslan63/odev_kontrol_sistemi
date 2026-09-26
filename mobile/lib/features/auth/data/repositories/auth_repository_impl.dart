import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/teacher_auth_preview.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';
import '../../../../core/utils/app_utils.dart';

/// AuthRepository'nin Firebase implementasyonu.
class AuthRepositoryImpl implements AuthRepository {
  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;
  AppUser? _cachedUser;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _firestore.collection('invite_codes');

  @override
  Stream<AppUser?> get authStateChanges {
    try {
      return _auth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser == null) {
          _cachedUser = null;
          return null;
        }
        // Kayıt/giriş az önce profili yazdıysa stream yarışını önle
        if (_cachedUser?.uid == firebaseUser.uid) {
          return _cachedUser;
        }

        AppUser? profile;
        for (var attempt = 0; attempt < 8; attempt++) {
          if (_cachedUser?.uid == firebaseUser.uid) {
            return _cachedUser;
          }
          try {
            profile = await getUserProfile(firebaseUser.uid);
            if (profile != null) break;
          } on AuthException {
            // permission-denied / kurallar gecikmesi — tekrar dene
          } catch (_) {}
          await Future<void>.delayed(
            Duration(milliseconds: 200 * (attempt + 1)),
          );
        }

        if (profile != null) {
          _cachedUser = profile;
          return profile;
        }
        if (_cachedUser?.uid == firebaseUser.uid) {
          return _cachedUser;
        }
        return null;
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Future<AppUser> registerTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user!;
      await createdUser.updateDisplayName(name.trim());

      final now = DateTime.now();
      final userModel = AppUserModel(
        uid: createdUser.uid,
        role: 'teacher',
        name: name.trim(),
        email: email.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _users.doc(createdUser.uid).set(userModel.toFirestore());

      await _firestore.collection('teacher_profiles').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': name.trim(),
        'email': email.trim(),
        'classCount': 0,
        'createdAt': now.toIso8601String(),
      });

      _cachedUser = userModel;
      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException &&
          (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        throw const AuthException(
          'Bu e-posta adresi zaten kayıtlı. Lütfen şifrenizle giriş yapınız.',
        );
      }
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      throw _mapException(e);
    }
  }

  @override
  Future<AppUser> registerParentWithPhone({
    required String name,
    required String phone,
    required String inviteCode,
    required String studentId,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException(
        'Telefon doğrulaması tamamlanmadı. Lütfen OTP adımını tekrarlayın.',
      );
    }

    try {
      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final resolvedStudentId = _resolveStudentId(codeData, studentId);
      final now = DateTime.now();
      final trimmedName = name.trim();
      final e164 = phone.trim();
      final syntheticEmail = _syntheticParentEmail(e164);

      final existing = await getUserProfile(firebaseUser.uid);
      if (existing != null && existing.role != 'parent') {
        await _auth.signOut();
        _cachedUser = null;
        throw const AuthException(
          'Bu telefon numarası veli hesabı için uygun değil.',
        );
      }

      await firebaseUser.updateDisplayName(trimmedName);

      final userModel = AppUserModel(
        uid: firebaseUser.uid,
        role: 'parent',
        name: trimmedName,
        email: syntheticEmail,
        phone: e164,
        isActive: true,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await _commitParentInviteBinding(
        uid: firebaseUser.uid,
        userModel: userModel,
        name: trimmedName,
        email: syntheticEmail,
        phone: e164,
        studentId: resolvedStudentId,
        inviteCode: inviteCode,
        inviteType: codeData['type'] as String? ?? 'student',
        now: now,
        mergeUser: existing != null,
      );

      _cachedUser = userModel;
      return userModel;
    } catch (e) {
      throw _mapException(e);
    }
  }

  String _syntheticParentEmail(String phoneE164) {
    final digits = phoneE164.replaceAll(RegExp(r'\D'), '');
    return '$digits@parents.eduly.local';
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email.trim());
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<TeacherAuthPreview> getTeacherAuthPreview(String email) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getTeacherAuthPreview');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email.trim().toLowerCase(),
      });
      final data = result.data;
      final exists = data['exists'] as bool? ?? false;
      final isTeacher = data['isTeacher'] as bool? ?? false;
      return TeacherAuthPreview(
        exists: exists,
        name: null,
        role: exists
            ? (isTeacher ? 'teacher' : 'parent')
            : null,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'E-posta kontrol edilemedi.');
    } catch (e) {
      throw _mapException(e);
    }
  }

  String _resolveStudentId(Map<String, dynamic> codeData, String studentId) {
    final type = codeData['type'] as String? ??
        (codeData['classId'] != null ? 'class' : 'student');

    if (type == 'class') {
      if (studentId.isEmpty) {
        throw const AuthException('Lütfen çocuğunuzu listeden seçin.');
      }
      final students = codeData['students'] as List<dynamic>? ?? [];
      final ids = students
          .whereType<Map>()
          .map((e) => e['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!ids.contains(studentId)) {
        throw const AuthException(
          'Seçilen öğrenci bu sınıf davet koduna ait değil.',
        );
      }
      return studentId;
    }

    final legacyId = codeData['studentId'] as String?;
    if (legacyId == null || legacyId.isEmpty) {
      throw const AuthException('Geçersiz davet kodu.');
    }
    return legacyId;
  }

  Future<void> _commitParentInviteBinding({
    required String uid,
    required AppUserModel userModel,
    required String name,
    required String email,
    required String phone,
    required String studentId,
    required String inviteCode,
    required String inviteType,
    required DateTime now,
    required bool mergeUser,
  }) async {
    final batch = _firestore.batch();

    // Sıra kritik (rules): users → students.parentIds → parent_profiles.studentIds
    if (mergeUser) {
      batch.set(
        _users.doc(uid),
        userModel.toFirestore(),
        SetOptions(merge: true),
      );
    } else {
      batch.set(_users.doc(uid), userModel.toFirestore());
    }

    batch.update(
      _firestore.collection('students').doc(studentId),
      {
        'parentIds': FieldValue.arrayUnion([uid]),
      },
    );

    if (mergeUser) {
      batch.set(
        _firestore.collection('parent_profiles').doc(uid),
        {
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'studentIds': FieldValue.arrayUnion([studentId]),
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.set(
        _firestore.collection('parent_profiles').doc(uid),
        {
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'studentIds': [studentId],
          'createdAt': now.toIso8601String(),
        },
      );
    }

    // Sınıf kodları yeniden kullanılabilir; yalnızca eski öğrenci kodlarını işaretle
    if (inviteType != 'class') {
      batch.update(
        _inviteCodes.doc(inviteCode),
        {
          'used': true,
          'usedBy': uid,
          'usedAt': now.toIso8601String(),
        },
      );
    }

    await batch.commit();
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
    String? expectedRole,
  }) async {
    try {
      final targetEmail = email.trim();
      if (!targetEmail.contains('@')) {
        throw const AuthException(
          'Lütfen geçerli bir e-posta adresi giriniz.',
        );
      }

      await _auth.signInWithEmailAndPassword(
        email: targetEmail,
        password: password,
      );

      final user = await getUserProfile(_auth.currentUser!.uid);
      if (user == null) {
        await _auth.signOut();
        throw const AuthException('Kullanıcı profili bulunamadı.');
      }

      if (expectedRole != null && user.role != expectedRole) {
        await _auth.signOut();
        _cachedUser = null;
        final label = expectedRole == 'teacher' ? 'öğretmen' : 'veli';
        throw AuthException(
          'Bu hesap $label girişi için uygun değil. Doğru rol sekmesini seçin.',
        );
      }

      if (user.isActive == false) {
        await _auth.signOut();
        _cachedUser = null;
        throw const AuthException('Hesabınız pasif durumda.');
      }

      _cachedUser = user;
      return user;
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try {
      await _users.doc(uid).delete();
      await _firestore.collection('teacher_profiles').doc(uid).delete();
      await _firestore.collection('parent_profiles').doc(uid).delete();
      await user.delete();
      _cachedUser = null;
      await _auth.signOut();
    } catch (e) {
      try {
        await _auth.signOut();
      } catch (_) {}
      _cachedUser = null;
      throw _mapException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromFirestore(doc.data()!, uid);
      }
    } on FirebaseException catch (e) {
      // Sessiz yutma: permission-denied profili null gösterip welcome'a atıyordu
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'Veritabanı erişim yetkisi yetersiz. Firestore kuralları deploy edilmiş mi?',
        );
      }
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    try {
      final normalized = code.trim().toUpperCase();
      if (!InviteCodeGenerator.isValid(normalized)) return null;

      final doc = await _inviteCodes.doc(normalized).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = Map<String, dynamic>.from(doc.data()!);
      data['code'] = doc.id;

      final type = data['type'] as String? ??
          (data['classId'] != null ? 'class' : 'student');
      data['type'] = type;

      final revoked = data['revoked'] as bool? ?? false;
      if (revoked) {
        throw const AuthException('Bu davet kodu iptal edilmiş.');
      }

      if (type != 'class') {
        final used = data['used'] as bool? ?? false;
        if (used) {
          throw const AuthException('Bu davet kodu daha önce kullanılmış.');
        }
      }

      final expiresAt = data['expiresAt'];
      if (expiresAt != null) {
        final DateTime expiry;
        if (expiresAt is String) {
          expiry = DateTime.parse(expiresAt);
        } else {
          expiry = (expiresAt as Timestamp).toDate();
        }
        if (DateTime.now().isAfter(expiry)) {
          throw const AuthException('Bu davet kodunun süresi dolmuş.');
        }
      }

      return data;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw _mapException(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw const AuthException('Şifre değiştirmek için e-posta hesabı gerekir.');
      }
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> linkStudentWithInviteCode({
    required String inviteCode,
    required String studentId,
  }) async {
    try {
      final user = _auth.currentUser;
      final profile = _cachedUser ??
          (user != null ? await getUserProfile(user.uid) : null);
      if (user == null || profile == null || !profile.isParent) {
        throw const AuthException('Yalnızca veli hesapları öğrenci bağlayabilir.');
      }

      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Davet kodu bulunamadı.');
      }

      final resolvedId = _resolveStudentId(codeData, studentId);
      final inviteType = codeData['type'] as String? ?? 'student';
      final now = DateTime.now();

      await _commitParentInviteBinding(
        uid: user.uid,
        userModel: AppUserModel.fromEntity(profile),
        name: profile.name,
        email: profile.email,
        phone: profile.phone ?? '',
        studentId: resolvedId,
        inviteCode: inviteCode.trim().toUpperCase(),
        inviteType: inviteType,
        now: now,
        mergeUser: true,
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> updateNotificationPrefs({
    required bool pushEnabled,
    required bool homeworkAlertsEnabled,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw const AuthException('Oturum bulunamadı.');
      }
      await _users.doc(uid).set(
        {
          'notificationPrefs': {
            'pushEnabled': pushEnabled,
            'homeworkAlertsEnabled': homeworkAlertsEnabled,
          },
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(Object e) {
    if (e is AuthException) return e;

    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          const AuthException('E-posta veya şifre hatalı.'),
        'invalid-verification-code' =>
          const AuthException('Doğrulama kodu hatalı.'),
        'session-expired' =>
          const AuthException('Kodun süresi doldu. Yeni kod isteyin.'),
        'invalid-phone-number' =>
          const AuthException('Geçersiz telefon numarası.'),
        'invalid-email' =>
          const AuthException('Geçersiz e-posta adresi biçimi.'),
        'email-already-in-use' =>
          const AuthException(
            'Bu e-posta adresi zaten kullanılıyor. Giriş yapmayı deneyin.',
          ),
        'weak-password' =>
          const AuthException(
            'Şifreniz çok zayıf. En az 6 karakter olmalıdır.',
          ),
        'user-disabled' =>
          const AuthException('Hesabınız devre dışı bırakılmıştır.'),
        'network-request-failed' =>
          const AuthException(
            'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.',
          ),
        'too-many-requests' =>
          const AuthException(
            'Çok fazla hatalı deneme yapıldı. Lütfen daha sonra tekrar deneyin.',
          ),
        _ => AuthException(
            'Giriş/Kayıt başarısız (${e.code}). Lütfen tekrar deneyin.',
          ),
      };
    }

    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return const AuthException('Veritabanı erişim yetkisi yetersiz.');
      }
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        return const AuthException('Sunucuya veya internete erişilemiyor.');
      }
      return AuthException(
        'İşlem başarısız (${e.code}): ${e.message ?? 'Lütfen tekrar deneyin.'}',
      );
    }

    return AuthException(e.toString().replaceAll('Exception: ', ''));
  }
}

/// Auth işlem hatası
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
