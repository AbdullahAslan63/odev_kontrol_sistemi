import 'dart:async';
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
  });

  final PhoneAuthState authState;
  final int cooldownSeconds;
  final bool canResend;
  final String? currentPhone;

  PhoneAuthUiState copyWith({
    PhoneAuthState? authState,
    int? cooldownSeconds,
    bool? canResend,
    String? currentPhone,
  }) {
    return PhoneAuthUiState(
      authState: authState ?? this.authState,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      canResend: canResend ?? this.canResend,
      currentPhone: currentPhone ?? this.currentPhone,
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
    );

    final completer = Completer<bool>();

    await _phoneAuthService.sendVerificationCode(
      rawPhone: e164Phone,
      onStateChanged: (newAuthState) {
        if (!mounted) return;
        state = state.copyWith(authState: newAuthState);
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
  Future<void> resendCode() async {
    if (!state.canResend || state.currentPhone == null) return;

    final codeSentState = state.authState is PhoneAuthCodeSent
        ? state.authState as PhoneAuthCodeSent
        : null;

    state = state.copyWith(authState: const PhoneAuthSending());

    await _phoneAuthService.sendVerificationCode(
      rawPhone: state.currentPhone!,
      forceResendingToken: codeSentState?.resendToken,
      onStateChanged: (newAuthState) {
        if (!mounted) return;
        state = state.copyWith(authState: newAuthState);
        if (newAuthState is PhoneAuthCodeSent) {
          _startCooldownTimer();
        } else if (newAuthState is PhoneAuthSignedIn) {
          _handleSuccessfulAuth();
        }
      },
    );
  }

  /// Kullanıcının girdiği 6 haneli OTP kodunu doğrular
  Future<bool> verifyCode(String code) async {
    if (state.authState is! PhoneAuthCodeSent) {
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Lütfen önce SMS doğrulama kodu isteyin.',
        ),
      );
      return false;
    }
    final codeSent = state.authState as PhoneAuthCodeSent;

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
        verificationId: codeSent.verificationId,
        smsCode: cleanCode,
      );

      if (credential.user != null) {
        final token = await credential.user!.getIdToken();
        if (!mounted) return false;
        state = state.copyWith(
          authState: PhoneAuthSignedIn(user: credential.user!, idToken: token),
        );
        _handleSuccessfulAuth();
        return true;
      }
      state = state.copyWith(
        authState: const PhoneAuthError(
          userMessage: 'Doğrulama başarısız oldu. Kullanıcı oluşturulamadı.',
        ),
      );
      return false;
    } catch (e) {
      final String message = e is FormatException
          ? e.message
          : FirebasePhoneAuthService.mapFirebaseError(e);
      if (mounted) {
        state = state.copyWith(
          authState: PhoneAuthError(userMessage: message),
        );
      }
      return false;
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
