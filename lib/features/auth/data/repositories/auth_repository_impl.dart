import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

/// AuthRepository'nin Firebase implementasyonu.
class AuthRepositoryImpl implements AuthRepository {
  FirebaseAuth? _authInstance;
  FirebaseFirestore? _firestoreInstance;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  // ── Koleksiyon referansları ─────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _firestore.collection('invite_codes');

  // ── Auth state akışı ────────────────────────────────────────────────────

  @override
  Stream<AppUser?> get authStateChanges {
    try {
      return _auth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser == null) return null;
        return getUserProfile(firebaseUser.uid);
      });
    } catch (e) {
      return Stream.value(null);
    }
  }

  @override
  AppUser? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return null;
  }

  // ── Kayıt ──────────────────────────────────────────────────────────────

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

      // Firestore'a kaydet
      await _users.doc(createdUser.uid).set(userModel.toFirestore());

      // Öğretmen profili oluştur
      await _firestore.collection('teacher_profiles').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': name.trim(),
        'email': email.trim(),
        'classCount': 0,
        'createdAt': now.toIso8601String(),
      });

      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException && (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          final user = credential.user!;
          await user.updateDisplayName(name.trim());

          final now = DateTime.now();
          final userModel = AppUserModel(
            uid: user.uid,
            role: 'teacher',
            name: name.trim(),
            email: email.trim(),
            isActive: true,
            createdAt: now,
            updatedAt: now,
          );

          await _users.doc(user.uid).set(userModel.toFirestore(), SetOptions(merge: true));
          await _firestore.collection('teacher_profiles').doc(user.uid).set({
            'uid': user.uid,
            'name': name.trim(),
            'email': email.trim(),
            'classCount': 0,
            'createdAt': now.toIso8601String(),
          }, SetOptions(merge: true));

          return userModel;
        } catch (_) {
          throw const AuthException('Bu e-posta adresi zaten kayıtlı. Lütfen Giriş Yap ekranından şifrenizle giriş yapınız.');
        }
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
  Future<AppUser> registerParent({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    User? createdUser;
    try {
      // Davet kodunu doğrula
      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user!;
      await createdUser.updateDisplayName(name.trim());

      final now = DateTime.now();
      final studentId = codeData['studentId'] as String;

      final userModel = AppUserModel(
        uid: createdUser.uid,
        role: 'parent',
        name: name.trim(),
        email: email.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Batch write — atomik işlem
      final batch = _firestore.batch();

      batch.set(_users.doc(createdUser.uid), userModel.toFirestore());

      batch.set(
        _firestore.collection('parent_profiles').doc(createdUser.uid),
        {
          'uid': createdUser.uid,
          'name': name.trim(),
          'email': email.trim(),
          'studentIds': [studentId],
          'createdAt': now.toIso8601String(),
        },
      );

      batch.update(
        _firestore.collection('students').doc(studentId),
        {
          'parentIds': FieldValue.arrayUnion([createdUser.uid]),
        },
      );

      batch.update(
        _inviteCodes.doc(inviteCode),
        {
          'used': true,
          'usedBy': createdUser.uid,
          'usedAt': now.toIso8601String(),
        },
      );

      await batch.commit();

      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException && (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          final user = credential.user!;
          await user.updateDisplayName(name.trim());

          final now = DateTime.now();
          final userModel = AppUserModel(
            uid: user.uid,
            role: 'parent',
            name: name.trim(),
            email: email.trim(),
            isActive: true,
            createdAt: now,
            updatedAt: now,
          );

          await _users.doc(user.uid).set(userModel.toFirestore(), SetOptions(merge: true));
          await _firestore.collection('parent_profiles').doc(user.uid).set({
            'uid': user.uid,
            'name': name.trim(),
            'email': email.trim(),
            'createdAt': now.toIso8601String(),
          }, SetOptions(merge: true));

          return userModel;
        } catch (_) {}
      }
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      throw _mapException(e);
    }
  }

  // ── Giriş ──────────────────────────────────────────────────────────────

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      String targetEmail = email.trim();

      if (!targetEmail.contains('@')) {
        final query = await _users
            .where('phone', isEqualTo: targetEmail)
            .get();
        if (query.docs.isNotEmpty) {
          targetEmail = query.docs.first.data()['email'] ?? targetEmail;
        } else {
          final nameQuery = await _users
              .where('name', isEqualTo: targetEmail)
              .get();
          if (nameQuery.docs.isNotEmpty) {
            targetEmail = nameQuery.docs.first.data()['email'] ?? targetEmail;
          }
        }
      }

      await _auth.signInWithEmailAndPassword(
        email: targetEmail,
        password: password,
      );

      final user = await getUserProfile(_auth.currentUser!.uid);
      if (user == null) throw const AuthException('Kullanıcı profili bulunamadı.');
      return user;
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Çıkış ──────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Kalıcı Hesap Silme ──────────────────────────────────────────────────

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı. Tekrar giriş yapın.');
    }

    final uid = user.uid;

    try {
      // Firebase Auth: uzun oturumlarda silme için yeniden doğrulama gerekir
      await _reauthenticateForDelete(user);

      // Firestore profil temizliği (yoksa sessizce geç)
      await _deleteDocQuietly(_firestore.collection('parent_profiles').doc(uid));
      await _deleteDocQuietly(_firestore.collection('teacher_profiles').doc(uid));
      await _deleteDocQuietly(_users.doc(uid));

      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _reauthenticateForDelete(user);
        await user.delete();
        return;
      }
      throw _mapException(e);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> _deleteDocQuietly(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (_) {}
  }

  /// Silme öncesi yeniden doğrulama (passless e-posta veya taze telefon oturumu).
  Future<void> _reauthenticateForDelete(User user) async {
    final email = user.email;
    final providers = user.providerData.map((p) => p.providerId).toSet();

    // Eski MatPusula passless veli hesapları
    if (email != null &&
        email.endsWith('@matpusula.app') &&
        email.startsWith('parent_')) {
      final phonePart = email.substring(
        'parent_'.length,
        email.indexOf('@'),
      );
      final credential = EmailAuthProvider.credential(
        email: email,
        password: 'MatPusula_Passless_$phonePart',
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    // Telefon ile giriş yapan veliler: silme için oturumun taze olması gerekir
    if (providers.contains('phone')) {
      final lastSignIn = user.metadata.lastSignInTime;
      final isFresh = lastSignIn != null &&
          DateTime.now().difference(lastSignIn) < const Duration(minutes: 5);
      if (!isFresh) {
        throw const AuthException(
          'Telefon hesabını silmek için: çıkış yap → aynı numarayla tekrar giriş yap → hemen Hesabı Sil.',
        );
      }
      return;
    }

    if (providers.contains('password')) {
      try {
        await user.reload();
      } catch (_) {}
    }
  }

  // ── Şifre sıfırlama ────────────────────────────────────────────────────

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<AppUser> signInOrRegisterParentWithPhone({
    required String phone,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final autoEmail = 'parent_$cleanPhone@matpusula.app';
    final autoPassword = 'MatPusula_Passless_$cleanPhone';

    // 1. Önce var olan e-posta / şifre ile giriş yapmayı dene
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: autoEmail,
        password: autoPassword,
      );
      final user = await getUserProfile(credential.user!.uid);
      if (user != null) {
        await _purgeDemoStudentsForParent(user.uid);
        return user;
      }
    } catch (_) {}

    // 2. Telefon numarası eşleşen veritabanı kullanıcısını ara
    try {
      final query = await _users
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final docData = query.docs.first.data();
        final existingEmail = docData['email'] as String?;
        if (existingEmail != null && existingEmail.isNotEmpty) {
          final credential = await _auth.signInWithEmailAndPassword(
            email: existingEmail,
            password: autoPassword,
          );
          final user = await getUserProfile(credential.user!.uid);
          if (user != null) {
            await _purgeDemoStudentsForParent(user.uid);
            return user;
          }
        }
      }
    } catch (_) {}

    // 3. Kullanıcı yoksa otomatik şifresiz Veli hesabı oluştur
    // Öğrenci SADECE öğretmen davet koduyla bağlanır — sahte Mustafa/demo yok.
    User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: autoEmail,
        password: autoPassword,
      );
      createdUser = credential.user!;
      final displayName = 'Veli (${phone.trim()})';
      await createdUser.updateDisplayName(displayName);

      final now = DateTime.now();
      final userModel = AppUserModel(
        uid: createdUser.uid,
        role: 'parent',
        name: displayName,
        email: autoEmail,
        phone: phone.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();
      batch.set(_users.doc(createdUser.uid), userModel.toFirestore());
      batch.set(
        _firestore.collection('parent_profiles').doc(createdUser.uid),
        {
          'uid': createdUser.uid,
          'name': displayName,
          'email': autoEmail,
          'phone': phone.trim(),
          'studentIds': <String>[],
          'createdAt': now.toIso8601String(),
        },
      );
      await batch.commit();
      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException &&
          (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: autoEmail,
            password: autoPassword,
          );
          final user = await getUserProfile(credential.user!.uid);
          if (user != null) {
            await _purgeDemoStudentsForParent(user.uid);
            return user;
          }
        } catch (_) {}
      }
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      throw _mapException(e);
    }
  }

  /// Eski demo (Mustafa Yıldız / teacher_demo) kayıtlarını veliden temizler.
  Future<void> _purgeDemoStudentsForParent(String parentUid) async {
    try {
      final snap = await _firestore
          .collection('students')
          .where('parentIds', arrayContains: parentUid)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['teacherId'] != 'teacher_demo') continue;

        final studentId = doc.id;
        final batch = _firestore.batch();

        final assigns = await _firestore
            .collection('homework_assignments')
            .where('studentId', isEqualTo: studentId)
            .get();
        for (final a in assigns.docs) {
          batch.delete(a.reference);
        }

        final exams = await _firestore
            .collection('exam_results')
            .where('studentId', isEqualTo: studentId)
            .get();
        for (final e in exams.docs) {
          batch.delete(e.reference);
        }

        batch.delete(_firestore.collection('homeworks').doc('hw_${parentUid}_1'));
        batch.delete(_firestore.collection('homeworks').doc('hw_${parentUid}_2'));
        batch.delete(doc.reference);
        await batch.commit();
      }

      // parent_profiles.studentIds'i gerçek bağlantılara göre yenile
      final realSnap = await _firestore
          .collection('students')
          .where('parentIds', arrayContains: parentUid)
          .get();
      final realIds = realSnap.docs
          .where((d) => d.data()['teacherId'] != 'teacher_demo')
          .map((d) => d.id)
          .toList();
      await _firestore.collection('parent_profiles').doc(parentUid).set(
        {'studentIds': realIds},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Temizlik başarısız olsa girişe engel olma
    }
  }

  @override
  Future<void> linkParentWithInviteCode({
    required String parentUid,
    required String inviteCode,
  }) async {
    try {
      final normalized = inviteCode.trim().toUpperCase();
      final codeData = await validateInviteCode(normalized);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final studentId = codeData['studentId'] as String?;
      if (studentId == null || studentId.isEmpty) {
        throw const AuthException('Davet kodunda öğrenci bilgisi yok.');
      }

      final studentRef = _firestore.collection('students').doc(studentId);
      final studentDoc = await studentRef.get();
      if (!studentDoc.exists) {
        throw const AuthException('Davet kodundaki öğrenci bulunamadı.');
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(studentRef, {
        'parentIds': FieldValue.arrayUnion([parentUid]),
      });
      batch.set(
        _firestore.collection('parent_profiles').doc(parentUid),
        {
          'studentIds': FieldValue.arrayUnion([studentId]),
        },
        SetOptions(merge: true),
      );
      batch.update(_inviteCodes.doc(normalized), {
        'used': true,
        'usedBy': parentUid,
        'usedAt': now.toIso8601String(),
      });
      await batch.commit();
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Profil getir ────────────────────────────────────────────────────────

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromFirestore(doc.data()!, uid);
      }
    } catch (_) {}

    final fbUser = _auth.currentUser;
    if (fbUser != null && fbUser.uid == uid) {
      final email = fbUser.email ?? '';
      final isParent = email.startsWith('parent_') || email.contains('parent');
      final role = isParent ? 'parent' : 'teacher';

      return AppUserModel(
        uid: uid,
        role: role,
        name: fbUser.displayName ?? (email.isNotEmpty ? email.split('@').first : 'Kullanıcı'),
        email: email,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  // ── Davet kodu doğrulama ────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    try {
      final doc = await _inviteCodes.doc(code).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final used = data['used'] as bool? ?? false;
      if (used) throw const AuthException('Bu davet kodu daha önce kullanılmış.');

      final expiresAt = data['expiresAt'];
      if (expiresAt != null) {
        DateTime expiry;
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

  // ── Genel Hata Dönüştürücü ──────────────────────────────────────────────

  Exception _mapException(Object e) {
    if (e is AuthException) return e;

    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          const AuthException('E-posta veya şifre hatalı.'),
        'invalid-email' =>
          const AuthException('Geçersiz e-posta adresi biçimi.'),
        'email-already-in-use' =>
          const AuthException('Bu e-posta adresi zaten kullanılıyor. Giriş yapmayı deneyin.'),
        'weak-password' =>
          const AuthException('Şifreniz çok zayıf. En az 6 karakter olmalıdır.'),
        'user-disabled' =>
          const AuthException('Hesabınız devre dışı bırakılmıştır.'),
        'network-request-failed' =>
          const AuthException('İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.'),
        'too-many-requests' =>
          const AuthException('Çok fazla hatalı deneme yapıldı. Lütfen daha sonra tekrar deneyin.'),
        'requires-recent-login' =>
          const AuthException(
            'Güvenlik için yeniden giriş gerekli. Çıkış yapıp tekrar giriş yapın, sonra hesabı silin.',
          ),
        _ => AuthException('İşlem başarısız (${e.code}). Lütfen tekrar deneyin.'),
      };
    }

    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return const AuthException('Veritabanı erişim yetkisi yetersiz.');
      }
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        return const AuthException('Sunucuya veya internete erişilemiyor.');
      }
      return AuthException('İşlem başarısız (${e.code}): ${e.message ?? 'Lütfen tekrar deneyin.'}');
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
