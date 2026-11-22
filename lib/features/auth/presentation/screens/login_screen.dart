import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../providers/auth_providers.dart';

/// Eduly Giriş Ekranı (Öğretmen & Veli — E-posta ve Şifre)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isTeacherRole = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    context.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isTeacherRole) {
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
    } else {
      await ref
          .read(parentAuthProvider.notifier)
          .signIn(email: email, password: password);
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
  }

  @override
  Widget build(BuildContext context) {
    final teacherState = ref.watch(teacherAuthProvider);
    final parentState = ref.watch(parentAuthProvider);
    final isLoading = teacherState.isLoading || parentState.isLoading;

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
                        onTap: () => setState(() => _isTeacherRole = true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _RoleTabButton(
                        title: 'Veli',
                        icon: Icons.family_restroom_rounded,
                        isSelected: !_isTeacherRole,
                        activeColor: AppColors.parentPrimary,
                        onTap: () => setState(() => _isTeacherRole = false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Giriş Formu ──────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: AppStrings.email,
                      hint: _isTeacherRole
                          ? 'ogretmen@okul.com'
                          : 'veli@eposta.com',
                      controller: _emailController,
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: activeColor,
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
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        color: activeColor,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitLogin(),
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
                            color: activeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: _isTeacherRole
                          ? 'Öğretmen Girişi Yap'
                          : 'Veli Girişi Yap',
                      onPressed: _submitLogin,
                      isLoading: isLoading,
                      backgroundColor: activeColor,
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
                          onPressed: () => context.push(
                            _isTeacherRole
                                ? '/register/teacher'
                                : '/register/parent',
                          ),
                          child: Text(
                            _isTeacherRole
                                ? 'Öğretmen Kaydı Oluştur'
                                : 'Davet Kodu ile Veli Kaydı',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: activeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
