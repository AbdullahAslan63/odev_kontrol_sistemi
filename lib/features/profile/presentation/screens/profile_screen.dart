import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';

/// Eduly Profil & Ayarlar Ekranı
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _prefNotifications = 'pref_notifications_enabled';
  static const _prefHomeworkAlerts = 'pref_homework_alerts_enabled';

  bool _notificationsEnabled = true;
  bool _homeworkAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = prefs.getBool(_prefNotifications) ?? true;
        _homeworkAlertsEnabled = prefs.getBool(_prefHomeworkAlerts) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _savePref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _showAddChildDialog() async {
    final codeController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: AppColors.parentPrimary),
                  SizedBox(width: 8),
                  Expanded(child: Text('Yeni Öğrenci/Çocuk Ekle')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Öğretmeninizden aldığınız davet kodunu girin:',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Davet Kodu',
                    hint: 'Örn: OT-A7K9M2',
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    prefixIcon: const Icon(
                      Icons.key_rounded,
                      color: AppColors.parentPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.parentPrimary,
                    minimumSize: const Size(96, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          final ok = await ref
                              .read(parentAuthProvider.notifier)
                              .linkChildWithInviteCode(code);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          if (ok) {
                            ref.invalidate(
                              parentStudentsStreamProvider(
                                ref.read(currentUserProvider)?.uid ?? '',
                              ),
                            );
                            context.showSnackBar('Öğrenci başarıyla bağlandı.');
                          } else {
                            final err =
                                ref.read(parentAuthProvider).errorMessage;
                            context.showSnackBar(
                              err ?? 'Davet kodu bağlanamadı.',
                              isError: true,
                            );
                            ref.read(parentAuthProvider.notifier).clearError();
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ekle', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(codeController.dispose);
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.teacherPrimary),
              SizedBox(width: 8),
              Expanded(child: Text('Şifre Değiştir')),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Mevcut Şifre',
                    hint: 'Mevcut şifreniz',
                    controller: oldPassController,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Mevcut şifre zorunludur.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Yeni Şifre',
                    hint: 'En az 8 karakter',
                    controller: newPassController,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Yeni şifre zorunludur.';
                      }
                      if (!v.isValidPassword) {
                        return 'Şifre en az 8 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teacherPrimary,
                minimumSize: const Size(110, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ref.read(authRepositoryProvider).changePassword(
                              currentPassword: oldPassController.text,
                              newPassword: newPassController.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        context.showSnackBar('Şifreniz başarıyla güncellendi.');
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (!mounted) return;
                        context.showSnackBar(
                          e.toString().replaceFirst('Exception: ', ''),
                          isError: true,
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Güncelle',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      oldPassController.dispose();
      newPassController.dispose();
    });
  }

  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: AppColors.info),
            SizedBox(width: 8),
            Expanded(child: Text('Gizlilik Politikası & KVKK')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Eduly Gizlilik Bildirimi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '1. Kişisel Verilerin İşlenmesi:\nKullanıcıların adı, e-posta adresi ve rol bilgileri yalnızca uygulama içi ödev, sınav ve duyuru süreçlerinin yürütülmesi amacıyla işlenir.\n\n'
                '2. Veri Güvenliği:\nTüm veriler Google Firebase bulut altyapısında şifreli ve yetkilendirilmiş erişim kuralları (Firestore Security Rules) ile korunur.\n\n'
                '3. Üçüncü Taraflarla Paylaşım:\nVerileriniz hiçbir reklam veren veya 3. taraf pazarlama şirketleri ile paylaşılmaz.\n\n'
                '4. Haklarınız:\nHesabınızı dilediğiniz zaman silebilir veya verilerinizin silinmesini talep edebilirsiniz.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              UrlUtils.openUrl(context, AppConstants.privacyPolicyUrl);
            },
            child: const Text('Web Sayfasını Aç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              minimumSize: const Size(110, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Kapat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(child: Text('Hesabı Kalıcı Olarak Sil?')),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hesabınızı sildiğinizde tüm profil bilgileriniz ve ilişkili verileriniz kalıcı olarak silinir. Bu işlem geri alınamaz.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Onay İçin Mevcut Şifreniz',
                    hint: 'Şifrenizi girin',
                    controller: passwordController,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Devam etmek için mevcut şifrenizi girin.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(124, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isDeleting = true);
                      try {
                        await ref.read(authRepositoryProvider).deleteAccount(
                              currentPassword: passwordController.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        context.showSnackBar('Hesabınız kalıcı olarak silindi.');
                        context.go('/welcome');
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isDeleting = false);
                        }
                        if (!mounted) return;
                        context.showSnackBar(
                          e.toString().replaceFirst('Exception: ', ''),
                          isError: true,
                        );
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hesabımı Sil',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(passwordController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isTeacher = user?.isTeacher ?? true;
    final primaryColor =
        isTeacher ? AppColors.teacherPrimary : AppColors.parentPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profil & Ayarlar',
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              // ── Kullanıcı Profil Kartı ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: primaryColor.withAlpha(30),
                      child: Icon(
                        isTeacher
                            ? Icons.school_rounded
                            : Icons.family_restroom_rounded,
                        color: primaryColor,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ??
                                (isTeacher
                                    ? 'Öğretmen Hesabı'
                                    : 'Veli Hesabı'),
                            style: AppTextStyles.h4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isTeacher
                                  ? '👨‍🏫 Öğretmen Hesabı'
                                  : '👨‍👩‍👧 Veli Hesabı',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Öğretmen Özel: Duyuru Geçmişi ────────────────────────────
              if (isTeacher) ...[
                _buildSettingsGroup('İletişim & Duyurular', [
                  _buildSettingsTile(
                    icon: Icons.campaign_outlined,
                    title: 'Gönderilen Duyurular',
                    subtitle: 'Velilere ilettiğiniz duyuru ve mesaj geçmişi',
                    onTap: () => context.push('/teacher/messages'),
                  ),
                ]),
                const SizedBox(height: 20),
              ],

              // ── Veli Özel: Çocuk Bağlantısı ve Yeni Çocuk Ekleme ─────────
              if (!isTeacher) ...[
                _buildSettingsGroup(
                  'Öğrenci / Çocuk Bağlantıları',
                  [
                    ...() {
                      final studentsAsync = ref.watch(
                        parentStudentsStreamProvider(user?.uid ?? ''),
                      );
                      final students =
                          studentsAsync.asData?.value ?? const [];
                      if (studentsAsync.isLoading) {
                        return [
                          const ListTile(
                            title: Text('Öğrenciler yükleniyor...'),
                            trailing: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          const Divider(height: 1),
                        ];
                      }
                      if (students.isEmpty) {
                        return [
                          const ListTile(
                            leading: Icon(
                              Icons.link_off_rounded,
                              color: AppColors.textSecondary,
                            ),
                            title: Text('Bağlı öğrenci yok'),
                            subtitle:
                                Text('Öğretmenden davet kodu alıp ekleyin'),
                          ),
                          const Divider(height: 1),
                        ];
                      }
                      return [
                        for (final s in students) ...[
                          _LinkedStudentTile(studentId: s.id, name: s.name, classId: s.classId, className: s.className, schoolNumber: s.schoolNumber),
                          const Divider(height: 1),
                        ],
                      ];
                    }(),
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.parentPrimary,
                      ),
                      title: const Text(
                        'Yeni Çocuk / Öğrenci Ekle',
                        style: TextStyle(
                          color: AppColors.parentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle:
                          const Text('Öğretmenden alınan davet kodu ile ekle'),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.parentPrimary,
                      ),
                      onTap: _showAddChildDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // ── Bildirim Tercihleri ───────────────────────────────────────
              _buildSettingsGroup('Bildirim Ayarları', [
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_rounded,
                    color: primaryColor,
                  ),
                  title: const Text(
                    'Uygulama İçi Bildirimler',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Duyuru ve mesaj bildirimlerini göster'),
                  value: _notificationsEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                    _savePref(_prefNotifications, val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: primaryColor,
                  ),
                  title: const Text(
                    'Ödev & Deneme Uyarıları',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle:
                      const Text('Yaklaşan ödev ve deneme hatırlatmaları'),
                  value: _homeworkAlertsEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    setState(() => _homeworkAlertsEnabled = val);
                    _savePref(_prefHomeworkAlerts, val);
                  },
                ),
              ]),
              const SizedBox(height: 20),

              // ── Güvenlik, Yasal & Destek ─────────────────────────────────
              _buildSettingsGroup('Güvenlik, Yasal & Destek', [
                _buildSettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Şifre Değiştir',
                  subtitle: 'Hesap şifrenizi güncelleyin',
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Gizlilik Politikası & KVKK',
                  subtitle: 'Kişisel verilerin korunması ve gizlilik özeti',
                  onTap: _showPrivacyPolicyDialog,
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Kullanım Koşulları',
                  subtitle: 'Hizmet şartlarını web tarayıcısında görüntüleyin',
                  onTap: () => UrlUtils.openUrl(context, AppConstants.termsUrl),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Destek & İletişim',
                  subtitle: AppConstants.supportEmail,
                  onTap: () => UrlUtils.openSupportEmail(context),
                ),
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Hesabımı Sil',
                  subtitle: 'Tüm kişisel verilerinizi kalıcı olarak silin',
                  onTap: _showDeleteAccountDialog,
                ),
              ]),
              const SizedBox(height: 32),

              // ── Çıkış Yap Butonu ─────────────────────────────────────────
              SecondaryButton(
                label: 'Güvenli Çıkış Yap',
                icon: Icons.logout_rounded,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (!context.mounted) return;
                  context.go('/welcome');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.labelLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textDisabled,
      ),
      onTap: onTap,
    );
  }
}

class _LinkedStudentTile extends ConsumerWidget {
  const _LinkedStudentTile({
    required this.studentId,
    required this.name,
    required this.classId,
    this.className,
    this.schoolNumber,
  });

  final String studentId;
  final String name;
  final String classId;
  final String? className;
  final String? schoolNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedClassName = className ??
        ref.watch(classByIdProvider(classId)).valueOrNull?.name;
    final classLabel =
        resolvedClassName != null && resolvedClassName.isNotEmpty
            ? '$resolvedClassName Sınıfı'
            : 'Kayıtlı Öğrenci';
    final noPart =
        schoolNumber != null && schoolNumber!.isNotEmpty
            ? ' • No: $schoolNumber'
            : '';

    return ListTile(
      leading: const Icon(Icons.face_rounded, color: AppColors.parentPrimary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$classLabel$noPart'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Bağlı',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
