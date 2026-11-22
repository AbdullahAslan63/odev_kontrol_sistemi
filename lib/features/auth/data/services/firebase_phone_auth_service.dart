import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/phone_number_helper.dart';

/// Firebase Telefon Kimlik Doğrulama Durum Modeli
sealed class PhoneAuthState {
  const PhoneAuthState();
}

class PhoneAuthIdle extends PhoneAuthState {
  const PhoneAuthIdle();
}

class PhoneAuthSending extends PhoneAuthState {
  const PhoneAuthSending();
}

class PhoneAuthCodeSent extends PhoneAuthState {
  const PhoneAuthCodeSent({
    required this.verificationId,
    this.resendToken,
    required this.maskedPhone,
  });

  final String verificationId;
  final int? resendToken;
  final String maskedPhone;
}

class PhoneAuthVerifying extends PhoneAuthState {
  const PhoneAuthVerifying();
}

class PhoneAuthSignedIn extends PhoneAuthState {
  const PhoneAuthSignedIn({
    required this.user,
    this.idToken,
  });

  final User user;
  final String? idToken;
}

class PhoneAuthError extends PhoneAuthState {
  const PhoneAuthError({
    required this.userMessage,
    this.errorCode,
  });

  final String userMessage;
  final String? errorCode;
}

/// Firebase Native Phone Authentication Servisi (Android Play Integrity / iOS APNs + reCAPTCHA / Web)
class FirebasePhoneAuthService {
  FirebasePhoneAuthService({FirebaseAuth? auth}) : _authInstance = auth;

  final FirebaseAuth? _authInstance;
  ConfirmationResult? _webConfirmationResult;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  /// SMS Doğrulama Kodu Gönder
  Future<void> sendVerificationCode({
    required String rawPhone,
    int? forceResendingToken,
    required void Function(PhoneAuthState state) onStateChanged,
  }) async {
    final e164Phone = PhoneNumberHelper.normalizeToE164(rawPhone);
    final maskedPhone = PhoneNumberHelper.maskPhoneNumber(e164Phone);

    onStateChanged(const PhoneAuthSending());

    try {
      await _auth.setLanguageCode('tr');

      if (kIsWeb) {
        _webConfirmationResult = await _auth.signInWithPhoneNumber(e164Phone);
        onStateChanged(
          PhoneAuthCodeSent(
            verificationId: _webConfirmationResult!.verificationId,
            resendToken: null,
            maskedPhone: maskedPhone,
          ),
        );
      } else {
        await _auth.verifyPhoneNumber(
          phoneNumber: e164Phone,
          timeout: const Duration(seconds: 60),
          forceResendingToken: forceResendingToken,
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              onStateChanged(const PhoneAuthVerifying());
              final userCredential =
                  await _auth.signInWithCredential(credential);
              if (userCredential.user != null) {
                final token = await userCredential.user!.getIdToken();
                onStateChanged(
                  PhoneAuthSignedIn(
                    user: userCredential.user!,
                    idToken: token,
                  ),
                );
              }
            } catch (e) {
              onStateChanged(
                PhoneAuthError(
                  userMessage: mapFirebaseError(e),
                  errorCode: e is FirebaseAuthException ? e.code : null,
                ),
              );
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            onStateChanged(
              PhoneAuthError(
                userMessage: mapFirebaseError(e),
                errorCode: e.code,
              ),
            );
          },
          codeSent: (String verificationId, int? resendToken) {
            onStateChanged(
              PhoneAuthCodeSent(
                verificationId: verificationId,
                resendToken: resendToken,
                maskedPhone: maskedPhone,
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } catch (e) {
      onStateChanged(
        PhoneAuthError(
          userMessage: mapFirebaseError(e),
          errorCode: e is FirebaseAuthException ? e.code : null,
        ),
      );
    }
  }

  /// Kullanıcının girdiği 6 haneli SMS OTP kodunu doğrula
  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final cleanCode = smsCode.trim();
    if (cleanCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      throw const FormatException(
        'Doğrulama kodu 6 haneli rakamlardan oluşmalıdır.',
      );
    }

    if (kIsWeb && _webConfirmationResult != null) {
      return _webConfirmationResult!.confirm(cleanCode);
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: cleanCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Aktif oturumun Firebase ID Token'ını alır
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Firebase Phone Auth hata kodlarını Türkçe mesajlara dönüştürür
  static String mapFirebaseError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
        case 'auth/invalid-phone-number':
          return 'Girilen telefon numarası geçersiz. Lütfen 05XX XXX XX XX biçiminde geçerli bir Türkiye cep numarası girin.';
        case 'invalid-verification-code':
        case 'auth/invalid-verification-code':
          return 'Girdiğiniz 6 haneli SMS doğrulama kodu hatalı.';
        case 'session-expired':
        case 'auth/session-expired':
        case 'code-expired':
        case 'auth/code-expired':
          return 'Doğrulama kodunun geçerlilik süresi dolmuş. Lütfen yeni bir kod isteyin.';
        case 'too-many-requests':
        case 'auth/too-many-requests':
          return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
        case 'quota-exceeded':
        case 'auth/quota-exceeded':
          return 'SMS gönderim limiti aşıldı. Lütfen daha sonra tekrar deneyin.';
        case 'operation-not-allowed':
        case 'auth/operation-not-allowed':
          return 'Firebase Console üzerinde Telefon Doğrulama (Phone) sağlayıcısı etkinleştirilmemiş.';
        case 'app-not-authorized':
        case 'auth/app-not-authorized':
          return 'Uygulama Firebase ile yetkilendirilemedi. SHA-1/SHA-256 parmak izi veya APNs ayarlarını kontrol edin.';
        case 'billing-not-enabled':
        case 'auth/billing-not-enabled':
          return 'SMS doğrulama hizmeti için Firebase faturalandırması etkinleştirilmelidir.';
        case 'captcha-check-failed':
        case 'auth/captcha-check-failed':
          return 'Güvenlik doğrulaması (reCAPTCHA) başarısız oldu. Lütfen tekrar deneyin.';
        case 'missing-client-identifier':
        case 'auth/missing-client-identifier':
          return 'Uygulama kimlik doğrulaması tamamlanamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
        case 'network-request-failed':
        case 'auth/network-request-failed':
          return 'İnternet bağlantınızı kontrol edip tekrar deneyin.';
        case 'user-disabled':
        case 'auth/user-disabled':
          return 'Bu telefon numarasına bağlı hesap Firebase üzerinde devre dışı bırakılmıştır. Hesabın etkinleştirilmesi için yönetici ile iletişime geçin.';
        case 'web-context-cancelled':
        case 'auth/web-context-cancelled':
          return 'Doğrulama penceresi kapatıldı. Lütfen tekrar deneyin.';
        case 'invalid-app-credential':
        case 'auth/invalid-app-credential':
          return 'Uygulama doğrulaması başarısız oldu. Lütfen tekrar deneyin.';
        case 'missing-verification-code':
        case 'auth/missing-verification-code':
          return 'Lütfen 6 haneli doğrulama kodunu girin.';
        default:
          return error.message ??
              'Telefon doğrulaması sırasında bir hata oluştu.';
      }
    }
    return 'Beklenmeyen bir hata oluştu: $error';
  }
}
