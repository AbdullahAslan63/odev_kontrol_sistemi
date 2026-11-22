import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

// ── Repository provider ──────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// ── Auth state akışı ─────────────────────────────────────────────────────────

/// Mevcut oturum durumu stream'i (gerçek zamanlı Firestore users/{uid} dinleyicisi).
/// null → giriş yok, AppUser → giriş var
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Giriş/kayıt tamamlandığında yönlendirme yarışını önlemek için senkron aktif kullanıcı.
final activeSessionUserProvider = StateProvider<AppUser?>((ref) => null);

/// Veli telefon doğrulaması ile kayıt Firestore yazımı bitene kadar router yönlendirmesini bekletir.
final isCompletingParentRegistrationProvider =
    StateProvider<bool>((ref) => false);

/// Mevcut oturum açmış kullanıcı (senkron ve reaktif erişim için)
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull ??
      ref.watch(activeSessionUserProvider);
});

// ── Auth işlem durumu ─────────────────────────────────────────────────────────

/// Auth ekranları için işlem durumu (giriş, kayıt, şifre sıfırlama)
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  AuthState get loading => const AuthState(isLoading: true);
  AuthState error(String message) => AuthState(errorMessage: message);
  AuthState get success => const AuthState(isSuccess: true);
}

// ── Öğretmen Auth Notifier ───────────────────────────────────────────────────

class TeacherAuthNotifier extends StateNotifier<AuthState> {
  TeacherAuthNotifier(this._repo, this._ref) : super(const AuthState());

  final AuthRepository _repo;
  final Ref _ref;

  Future<void> registerTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.loading;
    try {
      final user = await _repo.registerTeacher(
        name: name,
        email: email,
        password: password,
      );
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.loading;
    try {
      final user = await _repo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> signOut() async {
    _ref.read(activeSessionUserProvider.notifier).state = null;
    await _repo.signOut();
    state = const AuthState();
  }

  void clearError() => state = const AuthState();
}

final teacherAuthProvider =
    StateNotifierProvider<TeacherAuthNotifier, AuthState>((ref) {
  return TeacherAuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// ── Veli Auth Notifier ───────────────────────────────────────────────────────

class ParentAuthNotifier extends StateNotifier<AuthState> {
  ParentAuthNotifier(this._repo, this._ref) : super(const AuthState());

  final AuthRepository _repo;
  final Ref _ref;

  /// Davet kodu önizleme bilgisi
  Map<String, dynamic>? inviteCodeData;

  Future<bool> validateInviteCode(String code) async {
    state = state.loading;
    try {
      final data = await _repo.validateInviteCode(code);
      if (data == null) {
        state = state.error('Geçersiz davet kodu.');
        return false;
      }
      inviteCodeData = data;
      state = const AuthState();
      return true;
    } on AuthException catch (e) {
      state = state.error(e.message);
      return false;
    } catch (_) {
      state = state.error('Davet kodu doğrulanamadı.');
      return false;
    }
  }

  Future<void> registerParent({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    state = state.loading;
    try {
      final user = await _repo.registerParent(
        name: name,
        email: email,
        password: password,
        inviteCode: inviteCode,
      );
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> registerParentWithPhoneAuth({
    required String name,
    required String inviteCode,
  }) async {
    state = state.loading;
    try {
      final user = await _repo.registerParentWithPhoneAuth(
        name: name,
        inviteCode: inviteCode,
      );
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Veli kaydı tamamlanırken beklenmeyen bir hata oluştu.');
    }
  }

  Future<void> syncParentProfileAfterPhoneAuth() async {
    state = state.loading;
    try {
      final user = await _repo.syncParentProfileAfterPhoneAuth();
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Veli profili doğrulanırken bir hata oluştu.');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.loading;
    try {
      final user = await _repo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _ref.read(activeSessionUserProvider.notifier).state = user;
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('Beklenmeyen bir hata oluştu.');
    }
  }

  /// Öğretmen davet koduyla gerçek öğrenciyi veli hesabına bağlar
  Future<bool> linkChildWithInviteCode(String inviteCode) async {
    state = state.loading;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        state = state.error('Önce veli girişi yapmalısınız.');
        return false;
      }
      await _repo.linkParentWithInviteCode(
        parentUid: uid,
        inviteCode: inviteCode,
      );
      state = state.success;
      return true;
    } on AuthException catch (e) {
      state = state.error(e.message);
      return false;
    } catch (_) {
      state = state.error('Öğrenci bağlanırken bir hata oluştu.');
      return false;
    }
  }

  Future<void> signOut() async {
    _ref.read(activeSessionUserProvider.notifier).state = null;
    await _repo.signOut();
    state = const AuthState();
  }

  void clearError() => state = const AuthState();
}

final parentAuthProvider =
    StateNotifierProvider<ParentAuthNotifier, AuthState>((ref) {
  return ParentAuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// ── Şifre sıfırlama notifier ─────────────────────────────────────────────────

class PasswordResetNotifier extends StateNotifier<AuthState> {
  PasswordResetNotifier(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  Future<void> sendResetEmail(String email) async {
    state = state.loading;
    try {
      await _repo.sendPasswordResetEmail(email);
      state = state.success;
    } on AuthException catch (e) {
      state = state.error(e.message);
    } catch (_) {
      state = state.error('E-posta gönderilemedi.');
    }
  }

  void reset() => state = const AuthState();
}

final passwordResetProvider = StateNotifierProvider.autoDispose<
    PasswordResetNotifier, AuthState>((ref) {
  return PasswordResetNotifier(ref.watch(authRepositoryProvider));
});
