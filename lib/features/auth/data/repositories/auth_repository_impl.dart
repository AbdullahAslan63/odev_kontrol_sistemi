import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

/// AuthRepository'nin Firebase implementasyonu.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authInstance = auth,
        _firestoreInstance = firestore;

  final FirebaseAuth? _authInstance;
  final FirebaseFirestore? _firestoreInstance;
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
      return _auth.authStateChanges().asyncExpand((firebaseUser) {
        if (firebaseUser == null) {
          _cachedUser = null;
          return Stream<AppUser?>.value(null);
        }
        return _users.doc(firebaseUser.uid).snapshots().map((doc) {
          if (!doc.exists || doc.data() == null) {
            return null;
          }
          final appUser = AppUserModel.fromFirestore(doc.data()!, doc.id);
          _cachedUser = appUser;
          return appUser;
        }).handleError((_) => _cachedUser);
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  AppUser? get currentUser {
    try {
      if (_auth.currentUser == null) return null;
      return _cachedUser;
    } catch (_) {
      return _cachedUser;
    }
  }

  // ── Öğretmen Kaydı ──────────────────────────────────────────────────────

  @override
  Future<AppUser> registerTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    User? createdUser;
    final cleanEmail = email.trim();
    final cleanName = name.trim();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      createdUser = credential.user!;
      await createdUser.updateDisplayName(cleanName);

      final now = DateTime.now();
      final userModel = AppUserModel(
        uid: createdUser.uid,
        role: 'teacher',
        name: cleanName,
        email: cleanEmail,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();
      batch.set(_users.doc(createdUser.uid), userModel.toFirestore());
      batch.set(
        _firestore.collection('teacher_profiles').doc(createdUser.uid),
        {
          'uid': createdUser.uid,
          'name': cleanName,
          'email': cleanEmail,
          'classCount': 0,
          'createdAt': now.toIso8601String(),
        },
      );
      await batch.commit();

      _cachedUser = userModel;
      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException &&
          (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        throw const AuthException(
          'Bu e-posta adresi zaten kayıtlı. Lütfen Giriş Yap ekranından giriş yapınız.',
        );
      }
      if (createdUser != null) {
        try {
          await _deleteDocQuietly(
              _firestore.collection('teacher_profiles').doc(createdUser.uid));
          await _deleteDocQuietly(_users.doc(createdUser.uid));
          await createdUser.delete();
        } catch (_) {}
      }
      throw _mapException(e);
    }
  }

  // ── Veli Kaydı (E-posta + Şifre + Davet Kodu) ───────────────────────────

  @override
  Future<AppUser> registerParent({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    User? createdUser;
    final cleanEmail = email.trim();
    final cleanName = name.trim();

    try {
      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final resolvedCode =
          codeData['code'] as String? ?? inviteCode.trim().toUpperCase();
      final studentId = codeData['studentId'] as String? ?? '';
      if (studentId.isEmpty) {
        throw const AuthException('Davet kodunda öğrenci bilgisi bulunamadı.');
      }
      final classId = codeData['classId'] as String? ?? '';

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      createdUser = credential.user!;
      await createdUser.updateDisplayName(cleanName);

      final now = DateTime.now();
      final userModel = AppUserModel(
        uid: createdUser.uid,
        role: 'parent',
        name: cleanName,
        email: cleanEmail,
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
          'name': cleanName,
          'email': cleanEmail,
          'studentIds': [studentId],
          'classIds': classId.isNotEmpty ? [classId] : <String>[],
          'lastLinkedStudentId': studentId,
          'createdAt': now.toIso8601String(),
        },
      );
      batch.update(
        _firestore.collection('students').doc(studentId),
        {
          'parentIds': FieldValue.arrayUnion([createdUser.uid]),
          'lastInviteCode': resolvedCode,
        },
      );
      batch.update(
        _inviteCodes.doc(resolvedCode),
        {
          'used': true,
          'usedBy': createdUser.uid,
          'usedAt': Timestamp.fromDate(now),
        },
      );
      await batch.commit();

      _cachedUser = userModel;
      return userModel;
    } catch (e) {
      if (e is FirebaseAuthException &&
          (e.code == 'email-already-in-use' || e.code == 'EMAIL_EXISTS')) {
        throw const AuthException(
          'Bu e-posta adresi zaten kayıtlı. Giriş yaptıktan sonra Profil ekranından yeni öğrenci bağlayabilirsiniz.',
        );
      }
      if (createdUser != null) {
        try {
          await _deleteDocQuietly(
              _firestore.collection('parent_profiles').doc(createdUser.uid));
          await _deleteDocQuietly(_users.doc(createdUser.uid));
          await createdUser.delete();
        } catch (_) {}
      }
      throw _mapException(e);
    }
  }

  // ── Veli Kaydı (Doğrulanmış Firebase Phone Auth + Davet Kodu) ───────────

  @override
  Future<AppUser> registerParentWithPhoneAuth({
    required String name,
    required String inviteCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Telefon doğrulaması bulunamadı. Lütfen önce SMS kodunu doğrulayın.',
      );
    }

    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw const AuthException('Doğrulanmış telefon numarası bilgisi eksik.');
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AuthException('Ad soyad zorunludur.');
    }

    try {
      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final resolvedCode =
          codeData['code'] as String? ?? inviteCode.trim().toUpperCase();
      final studentId = codeData['studentId'] as String? ?? '';
      if (studentId.isEmpty) {
        throw const AuthException('Davet kodunda öğrenci bilgisi bulunamadı.');
      }
      final classId = codeData['classId'] as String? ?? '';

      await user.updateDisplayName(cleanName);

      final now = DateTime.now();
      final userModel = AppUserModel(
        uid: user.uid,
        role: 'parent',
        name: cleanName,
        email: user.email ?? '',
        phone: phone,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();
      batch.set(
        _users.doc(user.uid),
        userModel.toFirestore(),
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('parent_profiles').doc(user.uid),
        {
          'uid': user.uid,
          'name': cleanName,
          'phone': phone,
          'studentIds': FieldValue.arrayUnion([studentId]),
          'classIds': FieldValue.arrayUnion(
            classId.isNotEmpty ? [classId] : const <String>[],
          ),
          'lastLinkedStudentId': studentId,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
      batch.update(
        _firestore.collection('students').doc(studentId),
        {
          'parentIds': FieldValue.arrayUnion([user.uid]),
          'lastInviteCode': resolvedCode,
        },
      );
      batch.update(
        _inviteCodes.doc(resolvedCode),
        {
          'used': true,
          'usedBy': user.uid,
          'usedAt': Timestamp.fromDate(now),
        },
      );
      await batch.commit();

      _cachedUser = userModel;
      return userModel;
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Veli Phone Auth Girişi Sonrası Profil Senkronizasyonu ───────────────

  @override
  Future<AppUser> syncParentProfileAfterPhoneAuth() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Telefon doğrulaması bulunamadı. Lütfen yeniden giriş yapın.',
      );
    }

    try {
      final doc = await _users.doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final existing = AppUserModel.fromFirestore(doc.data()!, doc.id);
        _cachedUser = existing;
        return existing;
      }

      final phone = user.phoneNumber;
      final cleanName =
          (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : (phone != null && phone.isNotEmpty ? 'Veli ($phone)' : 'Veli');
      final now = DateTime.now();

      final newAppUser = AppUserModel(
        uid: user.uid,
        role: 'parent',
        name: cleanName,
        email: user.email ?? '',
        phone: phone,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();
      batch.set(_users.doc(user.uid), newAppUser.toFirestore());
      batch.set(
        _firestore.collection('parent_profiles').doc(user.uid),
        {
          'uid': user.uid,
          'name': cleanName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'studentIds': <String>[],
          'classIds': <String>[],
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
      await batch.commit();

      _cachedUser = newAppUser;
      return newAppUser;
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── E-posta / Şifre ile Giriş ───────────────────────────────────────────

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw const AuthException('Oturum açılamadı. Lütfen tekrar deneyin.');
      }

      final user = await getUserProfile(firebaseUser.uid);
      if (user == null) {
        await _auth.signOut();
        _cachedUser = null;
        throw const AuthException(
          'Kullanıcı profili bulunamadı. Lütfen yeniden kayıt olun veya destek ile iletişime geçin.',
        );
      }

      _cachedUser = user;
      return user;
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Çıkış ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await _auth.signOut();
  }

  // ── Şifre Değiştirme ────────────────────────────────────────────────────

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('Aktif oturum bulunamadı. Tekrar giriş yapın.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw const AuthException('Mevcut şifreniz hatalı.');
      }
      throw _mapException(e);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Kalıcı Hesap Silme ───────────────────────────────────────────────────

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı. Tekrar giriş yapın.');
    }

    final uid = user.uid;
    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');

    try {
      // 1. ÖNCE kimlik doğrulaması / taze oturum kontrolü
      if (hasPasswordProvider) {
        final email = user.email;
        if (email == null ||
            email.isEmpty ||
            currentPassword == null ||
            currentPassword.isEmpty) {
          throw const AuthException(
            'Devam etmek için mevcut şifrenizi girin.',
          );
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        final lastSignIn = user.metadata.lastSignInTime;
        if (lastSignIn == null ||
            DateTime.now().difference(lastSignIn) >
                const Duration(minutes: 5)) {
          throw const AuthException(
            'Güvenlik için lütfen çıkış yapıp telefon numaranızla yeniden giriş yaptıktan sonra hesabınızı silin.',
          );
        }
      }

      // 2. Kullanıcının rolünü ve ilişkili verilerini temizle
      final userDoc = await _users.doc(uid).get();
      final role = userDoc.data()?['role'] as String?;

      if (role == 'teacher') {
        await _cleanupTeacherData(uid);
      } else if (role == 'parent') {
        await _cleanupParentData(uid);
      } else {
        await _cleanupTeacherData(uid);
        await _cleanupParentData(uid);
      }

      // Kullanıcı profil belgelerini en son temizle (rules get() bağımlılıkları nedeniyle)
      await _deleteDocQuietly(_firestore.collection('teacher_profiles').doc(uid));
      await _deleteDocQuietly(_firestore.collection('parent_profiles').doc(uid));
      await _deleteDocQuietly(_users.doc(uid));

      // 3. Önbelleği sıfırla ve Firebase Auth hesabını sil
      _cachedUser = null;
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw const AuthException('Mevcut şifreniz hatalı.');
      }
      throw _mapException(e);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> _cleanupTeacherData(String teacherUid) async {
    const teacherCollections = [
      'homework_assignments',
      'homeworks',
      'exam_results',
      'subject_progress',
      'goals',
      'messages',
      'invite_codes',
      'students',
      'classes',
    ];

    final refsToDelete = <DocumentReference<Map<String, dynamic>>>[];

    for (final col in teacherCollections) {
      try {
        final snap = await _firestore
            .collection(col)
            .where('teacherId', isEqualTo: teacherUid)
            .get();
        refsToDelete.addAll(snap.docs.map((d) => d.reference));
      } catch (_) {}
    }

    try {
      final notifSnap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: teacherUid)
          .get();
      refsToDelete.addAll(notifSnap.docs.map((d) => d.reference));
    } catch (_) {}

    await _deleteRefsInChunks(refsToDelete);
  }

  Future<void> _cleanupParentData(String parentUid) async {
    try {
      final studentSnap = await _firestore
          .collection('students')
          .where('parentIds', arrayContains: parentUid)
          .get();

      for (var i = 0; i < studentSnap.docs.length; i += 400) {
        final chunk = studentSnap.docs.skip(i).take(400);
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'parentIds': FieldValue.arrayRemove([parentUid]),
          });
        }
        await batch.commit();
      }
    } catch (_) {}

    try {
      final notifSnap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: parentUid)
          .get();
      await _deleteRefsInChunks(notifSnap.docs.map((d) => d.reference).toList());
    } catch (_) {}
  }

  Future<void> _deleteRefsInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var i = 0; i < refs.length; i += 400) {
      final chunk = refs.skip(i).take(400);
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDocQuietly(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.delete();
    } catch (_) {}
  }

  // ── Şifre sıfırlama ─────────────────────────────────────────────────────

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> linkParentWithInviteCode({
    required String parentUid,
    required String inviteCode,
  }) async {
    try {
      final codeData = await validateInviteCode(inviteCode);
      if (codeData == null) {
        throw const AuthException('Geçersiz davet kodu.');
      }

      final resolvedCode =
          codeData['code'] as String? ?? inviteCode.trim().toUpperCase();
      final studentId = codeData['studentId'] as String?;
      if (studentId == null || studentId.isEmpty) {
        throw const AuthException('Davet kodunda öğrenci bilgisi yok.');
      }
      final classId = codeData['classId'] as String? ?? '';

      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(
        _firestore.collection('students').doc(studentId),
        {
          'parentIds': FieldValue.arrayUnion([parentUid]),
          'lastInviteCode': resolvedCode,
        },
      );
      batch.set(
        _firestore.collection('parent_profiles').doc(parentUid),
        {
          'uid': parentUid,
          'studentIds': FieldValue.arrayUnion([studentId]),
          'classIds': FieldValue.arrayUnion(
            classId.isNotEmpty ? [classId] : const <String>[],
          ),
          'lastLinkedStudentId': studentId,
        },
        SetOptions(merge: true),
      );
      batch.update(_inviteCodes.doc(resolvedCode), {
        'used': true,
        'usedBy': parentUid,
        'usedAt': Timestamp.fromDate(now),
      });
      await batch.commit();
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ── Profil getir ─────────────────────────────────────────────────────────

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUserModel.fromFirestore(doc.data()!, uid);
      }
    } catch (_) {}
    return null;
  }

  // ── Davet kodu doğrulama ─────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    var normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    try {
      var doc = await _inviteCodes.doc(normalized).get();
      if ((!doc.exists || doc.data() == null) &&
          !normalized.startsWith('OT-')) {
        final prefixed = 'OT-$normalized';
        final prefixedDoc = await _inviteCodes.doc(prefixed).get();
        if (prefixedDoc.exists && prefixedDoc.data() != null) {
          normalized = prefixed;
          doc = prefixedDoc;
        }
      }
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final used = data['used'] as bool? ?? false;
      if (used) {
        throw const AuthException('Bu davet kodu daha önce kullanılmış.');
      }

      final expiresAt = data['expiresAt'];
      if (expiresAt != null) {
        DateTime? expiry;
        if (expiresAt is String) {
          expiry = DateTime.tryParse(expiresAt);
        } else if (expiresAt is Timestamp) {
          expiry = expiresAt.toDate();
        }
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          throw const AuthException('Bu davet kodunun süresi dolmuş.');
        }
      }

      return {
        ...data,
        'code': normalized,
      };
    } catch (e) {
      if (e is AuthException) rethrow;
      throw _mapException(e);
    }
  }

  // ── Genel Hata Dönüştürücü ───────────────────────────────────────────────

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
        'email-already-in-use' ||
        'EMAIL_EXISTS' =>
          const AuthException(
              'Bu e-posta adresi zaten kullanılıyor. Giriş yapmayı deneyin.'),
        'weak-password' =>
          const AuthException('Şifreniz çok zayıf. En az 8 karakter olmalıdır.'),
        'user-disabled' =>
          const AuthException('Hesabınız devre dışı bırakılmıştır.'),
        'network-request-failed' =>
          const AuthException(
              'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.'),
        'too-many-requests' =>
          const AuthException(
              'Çok fazla hatalı deneme yapıldı. Lütfen daha sonra tekrar deneyin.'),
        'requires-recent-login' => const AuthException(
            'Güvenlik için yeniden giriş gerekli. Çıkış yapıp tekrar giriş yapın.',
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
      return AuthException(
          'İşlem başarısız (${e.code}): ${e.message ?? 'Lütfen tekrar deneyin.'}');
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
