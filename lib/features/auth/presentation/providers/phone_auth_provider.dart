import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/phone_number_helper.dart';
import '../../data/services/firebase_phone_auth_service.dart';
import 'auth_providers.dart';

export '../../data/services/firebase_phone_auth_service.dart';

class PhoneAuthUiState {
  const PhoneAuthUiState({
    this.authState = const PhoneAuthIdle(),
    this.cooldownSeconds = 0,
    this.canResend = false,
    this.currentPhone,
    this.verificationId,
    this.resendToken,
    this.maskedPhone,
  });

  final PhoneAuthState authState;
  final int cooldownSeconds;
  final bool canResend;
  final String? currentPhone;
  final String? verificationId;
  final int? resendToken;
  final String? maskedPhone;

  bool get hasVerificationSession =>
      verificationId != null && verificationId!.isNotEmpty;

  PhoneAuthUiState copyWith({
    PhoneAuthState? authState,
    int? cooldownSeconds,
    bool? canResend,
    String? currentPhone,
    String? verificationId,
    int? resendToken,
    String? maskedPhone,
    bool clearVerificationSession = false,
  }) {
    return PhoneAuthUiState(
      authState: authState ?? this.authState,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      canResend: canResend ?? this.canResend,
      currentPhone: currentPhone ?? this.currentPhone,
      verificationId:
          clearVerificationSession ? null : (verificationId ?? this.verificationId),
      resendToken:
          clearVerificationSession ? null : (resendToken ?? this.resendToken),
      maskedPhone:
          clearVerificationSession ? null : (maskedPhone ?? this.maskedPhone),
    );
  }
}

class PhoneAuthNotifier extends StateNotifier<PhoneAuthUiState> {
  PhoneAuthNotifier(this._phoneAuthService, this._ref)
      : super(const PhoneAuthUiState());

  final FirebasePhoneAuthService _phoneAuthService;
  final Ref _ref;
  Timer? _cooldownTimer;

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    state = state.copyWith(cooldownSeconds: 60, canResend: false);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.cooldownSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(cooldownSeconds: 0, canResend: true);
      } else {
        state = state.copyWith(cooldownSeconds: state.cooldownSeconds - 1);
      }
    });
  }

  /// Belirtilen cep telefonu numarasına Firebase SMS OTP kodu gönderir
  Future<bool> sendCode(String rawPhone) async {
    final clean = rawPhone.trim();
    if (clean.isEmpty) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Lütfen telefon numaranızı girin.',
        ),
      );
      return false;
    }

    if (!PhoneNumberHelper.isValidTurkishMobile(clean) &&
        !PhoneNumberHelper.isValidE164(clean)) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage:
              'Geçersiz telefon numarası. Lütfen 05XX XXX XX XX biçiminde geçerli cep numaranızı girin.',
        ),
      );
      return false;
    }

    String e164Phone;
    try {
      e164Phone = PhoneNumberHelper.normalizeToE164(clean);
    } catch (_) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Telefon numarası formatı geçersiz.',
        ),
      );
      return false;
    }

    state = state.copyWith(
      currentPhone: e164Phone,
      authState: const PhoneAuthSending(),
      clearVerificationSession: true,
    );

    final completer = Completer<bool>();

    await _phoneAuthService.sendVerificationCode(
      rawPhone: e164Phone,
      onStateChanged: (newAuthState) {
        if (!mounted) return;
        _applyServiceState(newAuthState);
        if (newAuthState is PhoneAuthCodeSent) {
          _startCooldownTimer();
          if (!completer.isCompleted) completer.complete(true);
        } else if (newAuthState is PhoneAuthSignedIn) {
          _handleSuccessfulAuth();
          if (!completer.isCompleted) completer.complete(true);
        } else if (newAuthState is PhoneAuthError) {
          if (!completer.isCompleted) completer.complete(false);
        }
      },
    );

    if (completer.isCompleted) {
      return completer.future;
    }
    return completer.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () {
        if (mounted &&
            (state.authState is PhoneAuthSending ||
                state.authState is PhoneAuthVerifying)) {
          state = state.copyWith(
            authState: const PhoneAuthError(
              userMessage:
                  'SMS doğrulama yanıtı zaman aşımına uğradı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
            ),
          );
        }
        return false;
      },
    );
  }

  /// Süre dolduğunda doğrulama kodunu tekrar gönderir
  Future<bool> resendCode() async {
    if (!state.canResend || state.currentPhone == null) return false;

    state = state.copyWith(authState: const PhoneAuthSending());
    final completer = Completer<bool>();

    await _phoneAuthService.sendVerificationCode(
      rawPhone: state.currentPhone!,
      forceResendingToken: state.resendToken,
      onStateChanged: (newAuthState) {
        if (!mounted) return;
        _applyServiceState(newAuthState);
        if (newAuthState is PhoneAuthCodeSent) {
          _startCooldownTimer();
          if (!completer.isCompleted) completer.complete(true);
        } else if (newAuthState is PhoneAuthSignedIn) {
          _handleSuccessfulAuth();
          if (!completer.isCompleted) completer.complete(true);
        } else if (newAuthState is PhoneAuthError) {
          if (!completer.isCompleted) completer.complete(false);
        }
      },
    );

    if (completer.isCompleted) {
      return completer.future;
    }
    return completer.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () {
        if (mounted &&
            (state.authState is PhoneAuthSending ||
                state.authState is PhoneAuthVerifying)) {
          state = state.copyWith(
            authState: const PhoneAuthError(
              userMessage:
                  'SMS doğrulama yanıtı zaman aşımına uğradı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
            ),
          );
        }
        return false;
      },
    );
  }

  /// Kullanıcının girdiği 6 haneli OTP kodunu doğrular
  Future<bool> verifyCode(
    String code, {
    bool invalidateAuth = true,
  }) async {
    final verificationId = state.verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Lütfen önce SMS doğrulama kodu isteyin.',
        ),
      );
      return false;
    }

    final cleanCode = code.trim();
    if (cleanCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Doğrulama kodu 6 haneli rakamlardan oluşmalıdır.',
        ),
      );
      return false;
    }

    state = state.copyWith(authState: const PhoneAuthVerifying());

    try {
      final credential = await _phoneAuthService.verifyOtpCode(
        verificationId: verificationId,
        smsCode: cleanCode,
      );

      if (credential.user != null) {
        final token = await credential.user!.getIdToken();
        if (!mounted) return false;
        state = state.copyWith(
          authState: PhoneAuthSignedIn(user: credential.user!, idToken: token),
          clearVerificationSession: true,
        );
        if (invalidateAuth) {
          _handleSuccessfulAuth();
        }
        return true;
      }
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Doğrulama başarısız oldu. Kullanıcı oluşturulamadı.',
        ),
      );
      return false;
    } catch (e) {
      final errorCode = e is FirebaseAuthException ? e.code : null;
      final isExpired = errorCode == 'session-expired' ||
          errorCode == 'auth/session-expired' ||
          errorCode == 'code-expired' ||
          errorCode == 'auth/code-expired';
      final message = e is FormatException
          ? e.message
          : FirebasePhoneAuthService.mapFirebaseError(e);
      if (mounted) {
        state = state.copyWith(
          authState: PhoneAuthError(
            userMessage: message,
            errorCode: errorCode,
          ),
          clearVerificationSession: isExpired,
        );
      }
      return false;
    }
  }

  void _applyServiceState(PhoneAuthState newAuthState) {
    if (newAuthState is PhoneAuthCodeSent) {
      state = state.copyWith(
        authState: newAuthState,
        verificationId: newAuthState.verificationId,
        resendToken: newAuthState.resendToken,
        maskedPhone: newAuthState.maskedPhone,
      );
    } else if (newAuthState is PhoneAuthSignedIn) {
      state = state.copyWith(
        authState: newAuthState,
        clearVerificationSession: true,
      );
    } else {
      state = state.copyWith(authState: newAuthState);
    }
  }

  void _handleSuccessfulAuth() {
    _ref.invalidate(authStateProvider);
  }

  void reset() {
    _cooldownTimer?.cancel();
    state = const PhoneAuthUiState();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

final firebasePhoneAuthServiceProvider =
    Provider<FirebasePhoneAuthService>((ref) {
  return FirebasePhoneAuthService();
});

final phoneAuthNotifierProvider = StateNotifierProvider.autoDispose<
    PhoneAuthNotifier, PhoneAuthUiState>((ref) {
  final service = ref.watch(firebasePhoneAuthServiceProvider);
  return PhoneAuthNotifier(service, ref);
});
