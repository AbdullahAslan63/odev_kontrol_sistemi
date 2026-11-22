import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/phone_number_helper.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../providers/auth_providers.dart';
import '../providers/phone_auth_provider.dart';

/// Eduly Giriş Ekranı
/// - Öğretmen: E-posta + Şifre
/// - Veli: Gerçek Firebase Telefon Numarası + SMS Doğrulama Kodu
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _teacherFormKey = GlobalKey<FormState>();
  final _parentFormKey = GlobalKey<FormState>();

  // Öğretmen alanları
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Veli alanları (Telefon Numarası + SMS OTP)
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isTeacherRole = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitTeacherLogin() async {
    context.unfocus();
    if (!_teacherFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref
        .read(teacherAuthProvider.notifier)
        .signIn(email: email, password: password);
    if (!mounted) return;

    final state = ref.read(teacherAuthProvider);
    if (state.isSuccess) {
      final user = ref.read(currentUserProvider);
      context.go(
        user?.isParent == true ? '/parent/home' : '/teacher/home',
      );
    } else if (state.errorMessage != null) {
      context.showSnackBar(state.errorMessage!, isError: true);
      ref.read(teacherAuthProvider.notifier).clearError();
    }
  }

  Future<void> _sendParentSms() async {
    context.unfocus();
    final rawPhone = _phoneController.text.trim();
    if (!PhoneNumberHelper.isValidTurkishMobile(rawPhone) &&
        !PhoneNumberHelper.isValidE164(rawPhone)) {
      context.showSnackBar(
        'Lütfen 05XX XXX XX XX biçiminde geçerli bir cep telefonu numarası girin.',
        isError: true,
      );
      return;
    }

    final ok = await ref
        .read(phoneAuthNotifierProvider.notifier)
        .sendCode(rawPhone);
    if (!mounted) return;

    final phoneState = ref.read(phoneAuthNotifierProvider);
    if (ok && phoneState.authState is PhoneAuthSignedIn) {
      await _finishParentPhoneLogin();
    } else if (!ok && phoneState.authState is PhoneAuthError) {
      context.showSnackBar(
        (phoneState.authState as PhoneAuthError).userMessage,
        isError: true,
      );
    }
  }

  Future<void> _submitParentLogin() async {
    context.unfocus();
    if (!_parentFormKey.currentState!.validate()) return;

    final phoneState = ref.read(phoneAuthNotifierProvider);
    if (phoneState.authState is PhoneAuthSignedIn) {
      await _finishParentPhoneLogin();
      return;
    }

    if (phoneState.authState is! PhoneAuthCodeSent) {
      await _sendParentSms();
      return;
    }

    final verified = await ref
        .read(phoneAuthNotifierProvider.notifier)
        .verifyCode(_otpController.text.trim());
    if (!mounted) return;

    if (!verified) {
      final err = ref.read(phoneAuthNotifierProvider).authState;
      if (err is PhoneAuthError) {
        context.showSnackBar(err.userMessage, isError: true);
      }
      return;
    }

    await _finishParentPhoneLogin();
  }

  Future<void> _finishParentPhoneLogin() async {
    await ref
        .read(parentAuthProvider.notifier)
        .syncParentProfileAfterPhoneAuth();
    if (!mounted) return;

    final state = ref.read(parentAuthProvider);
    if (state.isSuccess) {
      final user = ref.read(currentUserProvider);
      context.go(
        user?.isTeacher == true ? '/teacher/home' : '/parent/home',
      );
    } else if (state.errorMessage != null) {
      context.showSnackBar(state.errorMessage!, isError: true);
      ref.read(parentAuthProvider.notifier).clearError();
    }
  }

  void _switchRole(bool isTeacher) {
    if (_isTeacherRole == isTeacher) return;
    context.unfocus();
    setState(() => _isTeacherRole = isTeacher);
    ref.read(teacherAuthProvider.notifier).clearError();
    ref.read(parentAuthProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final teacherState = ref.watch(teacherAuthProvider);
    final parentState = ref.watch(parentAuthProvider);
    final phoneUiState = ref.watch(phoneAuthNotifierProvider);
    final phoneAuth = phoneUiState.authState;

    final isTeacherLoading = teacherState.isLoading;
    final isParentLoading = parentState.isLoading ||
        phoneAuth is PhoneAuthSending ||
        phoneAuth is PhoneAuthVerifying;

    final activeColor =
        _isTeacherRole ? AppColors.teacherPrimary : AppColors.parentPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding * 1.2,
            vertical: AppSizes.pagePadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Eduly Logo & Başlık ───────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const EdulyLogo(size: 84),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.h1.copyWith(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ödev & Eğitim Takip Platformu',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Kullanıcı Türü Seçimi (Öğretmen / Veli) ──────────────────
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _RoleTabButton(
                        title: 'Öğretmen',
                        icon: Icons.school_rounded,
                        isSelected: _isTeacherRole,
                        activeColor: AppColors.teacherPrimary,
                        onTap: () => _switchRole(true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _RoleTabButton(
                        title: 'Veli',
                        icon: Icons.family_restroom_rounded,
                        isSelected: !_isTeacherRole,
                        activeColor: AppColors.parentPrimary,
                        onTap: () => _switchRole(false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isTeacherRole)
                _buildTeacherForm(isTeacherLoading)
              else
                _buildParentForm(phoneUiState, isParentLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherForm(bool isLoading) {
    return Form(
      key: _teacherFormKey,
      child: Column(
        children: [
          AppTextField(
            label: AppStrings.email,
            hint: 'ogretmen@okul.com',
            controller: _emailController,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.teacherPrimary,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return AppStrings.errorEmailRequired;
              }
              if (!v.trim().isValidEmail) {
                return AppStrings.errorEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.itemSpacing),
          AppTextField(
            label: AppStrings.password,
            hint: 'Şifrenizi girin',
            controller: _passwordController,
            isPassword: true,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.teacherPrimary,
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitTeacherLogin(),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return AppStrings.errorPasswordRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: Text(
                'Şifremi Unuttum?',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.teacherPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Öğretmen Girişi Yap',
            onPressed: _submitTeacherLogin,
            isLoading: isLoading,
            backgroundColor: AppColors.teacherPrimary,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Hesabınız yok mu? ',
                style: AppTextStyles.bodyMedium,
              ),
              TextButton(
                onPressed: () => context.push('/register/teacher'),
                child: Text(
                  'Öğretmen Kaydı Oluştur',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.teacherPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParentForm(PhoneAuthUiState phoneUiState, bool isLoading) {
    final phoneAuth = phoneUiState.authState;
    final hasCodeSent = phoneAuth is PhoneAuthCodeSent;
    final isSignedIn = phoneAuth is PhoneAuthSignedIn;

    return Form(
      key: _parentFormKey,
      child: Column(
        children: [
          AppTextField(
            label: 'Telefon Numarası',
            hint: '05XX XXX XX XX',
            controller: _phoneController,
            enabled: !hasCodeSent && !isSignedIn,
            prefixIcon: const Icon(
              Icons.phone_android_rounded,
              color: AppColors.parentPrimary,
            ),
            keyboardType: TextInputType.phone,
            textInputAction:
                hasCodeSent ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!hasCodeSent && !isSignedIn) {
                _sendParentSms();
              }
            },
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Telefon numarası zorunludur.';
              }
              if (!PhoneNumberHelper.isValidTurkishMobile(v.trim()) &&
                  !PhoneNumberHelper.isValidE164(v.trim())) {
                return 'Lütfen 05XX XXX XX XX biçiminde geçerli bir numara girin.';
              }
              return null;
            },
          ),
          if (hasCodeSent) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.parentSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.parentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sms_outlined,
                    color: AppColors.parentPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SMS doğrulama kodu ${phoneAuth.maskedPhone} numarasına gönderildi.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'SMS Doğrulama Kodu',
              hint: '6 haneli kod',
              controller: _otpController,
              prefixIcon: const Icon(
                Icons.pin_outlined,
                color: AppColors.parentPrimary,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitParentLogin(),
              validator: (v) {
                final clean = v?.trim() ?? '';
                if (clean.length != 6) {
                  return 'Lütfen 6 haneli SMS kodunu girin.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          _otpController.clear();
                          ref.read(phoneAuthNotifierProvider.notifier).reset();
                        },
                  child: const Text(
                    'Numarayı Değiştir',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: (isLoading || !phoneUiState.canResend)
                      ? null
                      : () => ref
                          .read(phoneAuthNotifierProvider.notifier)
                          .resendCode(),
                  child: Text(
                    phoneUiState.canResend
                        ? 'Kodu Tekrar Gönder'
                        : 'Tekrar gönder (${phoneUiState.cooldownSeconds} sn)',
                    style: TextStyle(
                      color: phoneUiState.canResend
                          ? AppColors.parentPrimary
                          : AppColors.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isSignedIn) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Telefonunuz otomatik doğrulandı. Girişi tamamlamak için devam edin.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: hasCodeSent
                ? 'Doğrula ve Veli Girişi Yap'
                : (isSignedIn
                    ? 'Veli Girişini Tamamla'
                    : 'SMS Doğrulama Kodu Gönder'),
            onPressed:
                (hasCodeSent || isSignedIn) ? _submitParentLogin : _sendParentSms,
            isLoading: isLoading,
            backgroundColor: AppColors.parentPrimary,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'İlk kez mi kullanıyorsunuz? ',
                style: AppTextStyles.bodyMedium,
              ),
              TextButton(
                onPressed: () => context.push('/register/parent'),
                child: Text(
                  'Davet Kodu ile Veli Kaydı',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.parentPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleTabButton extends StatelessWidget {
  const _RoleTabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
