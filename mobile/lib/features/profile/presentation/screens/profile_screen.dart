import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Eduly Profil & Ayarlar Ekranı
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _homeworkAlertsEnabled = true;
  bool _prefsLoaded = false;
  bool _savingPrefs = false;
  List<_LinkedStudent> _linkedStudents = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrefsAndStudents();
    });
  }

  Future<void> _loadPrefsAndStudents() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .get();
      final prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
      if (prefs != null && mounted) {
        setState(() {
          _notificationsEnabled = prefs['pushEnabled'] as bool? ?? true;
          _homeworkAlertsEnabled =
              prefs['homeworkAlertsEnabled'] as bool? ?? true;
          _prefsLoaded = true;
        });
      } else if (mounted) {
        setState(() => _prefsLoaded = true);
      }

      if (user.isParent) {
        final profile = await FirebaseFirestore.instance
            .collection(AppConstants.colParentProfiles)
            .doc(user.uid)
            .get();
        final ids = List<String>.from(
          profile.data()?['studentIds'] as List? ?? [],
        );
        final docs = await Future.wait(
          ids.map(
            (id) => FirebaseFirestore.instance
                .collection(AppConstants.colStudents)
                .doc(id)
                .get(),
          ),
        );
        final students = <_LinkedStudent>[];
        for (final s in docs) {
          if (s.exists) {
            final data = s.data()!;
            students.add(
              _LinkedStudent(
                id: s.id,
                name: data['name'] as String? ?? 'Öğrenci',
                schoolNumber: data['schoolNumber'] as String?,
              ),
            );
          }
        }
        if (mounted) setState(() => _linkedStudents = students);
      }
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _persistNotificationPrefs({
    required bool pushEnabled,
    required bool homeworkAlertsEnabled,
  }) async {
    setState(() => _savingPrefs = true);
    try {
      await ref.read(authRepositoryProvider).updateNotificationPrefs(
            pushEnabled: pushEnabled,
            homeworkAlertsEnabled: homeworkAlertsEnabled,
          );
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = pushEnabled;
        _homeworkAlertsEnabled = homeworkAlertsEnabled;
      });
    } on AuthException catch (e) {
      if (mounted) context.showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Bildirim tercihi kaydedilemedi', isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  void _showAddChildDialog() {
    final codeController = TextEditingController();
    final studentIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Text('Yeni Öğrenci/Çocuk Ekle'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sınıf davet kodunu ve listeden seçtiğiniz öğrenci kimliğini girin. '
              'Tek öğrenci kodlarında kimlik alanı boş bırakılabilir.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Sınıf Davet Kodu',
              hint: AppStrings.inviteCodeHint,
              controller: codeController,
              prefixIcon: const Icon(Icons.key_rounded,
                  color: AppColors.parentPrimary),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Öğrenci ID (sınıf kodu için)',
              hint: 'Davet ekranındaki öğrenci kimliği',
              controller: studentIdController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final validated = await ref
                    .read(authRepositoryProvider)
                    .validateInviteCode(code);
                if (validated == null) {
                  if (mounted) {
                    context.showSnackBar('Davet kodu bulunamadı', isError: true);
                  }
                  return;
                }
                final type = validated['type'] as String? ?? 'student';
                var studentId = studentIdController.text.trim();
                if (type == 'class') {
                  final students =
                      validated['students'] as List<dynamic>? ?? [];
                  if (studentId.isEmpty && students.length == 1) {
                    final first = students.first;
                    if (first is Map) {
                      studentId = first['id'] as String? ?? '';
                    }
                  }
                  if (studentId.isEmpty) {
                    if (mounted) {
                      context.showSnackBar(
                        'Sınıf kodu için öğrenci ID gerekli',
                        isError: true,
                      );
                    }
                    return;
                  }
                } else {
                  studentId = validated['studentId'] as String? ?? studentId;
                }
                await ref.read(authRepositoryProvider).linkStudentWithInviteCode(
                      inviteCode: code,
                      studentId: studentId,
                    );
                if (!mounted) return;
                context.showSnackBar('Öğrenci hesabınıza bağlandı');
                await _loadPrefsAndStudents();
              } on AuthException catch (e) {
                if (mounted) context.showSnackBar(e.message, isError: true);
              } catch (_) {
                if (mounted) {
                  context.showSnackBar('Bağlama başarısız', isError: true);
                }
              }
            },
            child: Text('Ekle', style: AppTextStyles.buttonMedium),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.teacherPrimary),
            SizedBox(width: 8),
            Text('Şifre Değiştir'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Mevcut Şifre',
              hint: 'Mevcut şifreniz',
              controller: oldPassController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Yeni Şifre',
              hint: 'En az 6 karakter',
              controller: newPassController,
              isPassword: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teacherPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (newPassController.text.length < 6) {
                context.showSnackBar('Şifre en az 6 karakter olmalıdır',
                    isError: true);
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(authRepositoryProvider).changePassword(
                      currentPassword: oldPassController.text,
                      newPassword: newPassController.text,
                    );
                if (mounted) {
                  context.showSnackBar('Şifreniz güncellendi');
                }
              } on AuthException catch (e) {
                if (mounted) context.showSnackBar(e.message, isError: true);
              } catch (_) {
                if (mounted) {
                  context.showSnackBar('Şifre güncellenemedi', isError: true);
                }
              }
            },
            child: Text('Güncelle', style: AppTextStyles.buttonMedium),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: AppColors.info),
            SizedBox(width: 8),
            Text('Gizlilik Politikası & KVKK'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Eduly Gizlilik Bildirimi',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '1. Kişisel Verilerin İşlenmesi:\nKullanıcıların adı, e-posta adresi ve rol bilgileri yalnızca uygulama içi ödev, sınav ve duyuru süreçlerinin yürütülmesi amacıyla işlenir.\n\n'
                '2. Veri Güvenliği:\nTüm veriler Google Firebase bulut altyapısında şifreli ve yetkilendirilmiş erişim kuralları (Firestore Security Rules) ile korunur.\n\n'
                '3. Üçüncü Taraflarla Paylaşım:\nVerileriniz hiçbir reklam veren veya 3. taraf pazarlama şirketleri ile paylaşılmaz.\n\n'
                '4. Haklarınız:\nHesabınızı dilediğiniz zaman silebilir veya verilerinizin silinmesini talep edebilirsiniz.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(AppConstants.privacyPolicyUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Tam metin'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Okudum ve Anladım', style: AppTextStyles.buttonMedium),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Hesabı Sil?'),
          ],
        ),
        content: Text(
          'Hesabınızı sildiğinizde profil verileriniz ve bağlantılarınız sistemden kalıcı olarak temizlenir. Bu işlem geri alınamaz.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).deleteAccount();
              if (!mounted) return;
              context.showSnackBar(
                  'Hesabınız ve profil verileriniz Firebase\'den kalıcı olarak silindi.');
              context.go('/welcome');
            },
            child: Text('Hesabımı Sil', style: AppTextStyles.buttonMedium),
          ),
        ],
      ),
    );
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
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isTeacher ? 'Öğretmen Hesabı' : 'Veli Hesabı',
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
              if (!isTeacher) ...[
                _buildSettingsGroup('Öğrenci / Çocuk Bağlantıları', [
                  if (_linkedStudents.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded,
                          color: AppColors.parentPrimary),
                      title: Text('Henüz bağlı öğrenci yok',
                          style: AppTextStyles.labelLarge),
                      subtitle: const Text('Davet kodu ile ekleyin'),
                    )
                  else
                    ..._linkedStudents.map(
                      (s) => ListTile(
                        leading: const Icon(Icons.face_rounded,
                            color: AppColors.parentPrimary),
                        title: Text(s.name, style: AppTextStyles.h4),
                        subtitle: Text(
                          s.schoolNumber != null
                              ? 'No: ${s.schoolNumber}'
                              : 'Bağlı öğrenci',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Bağlı',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.parentPrimary),
                    title: Text(
                      'Yeni Çocuk / Öğrenci Ekle',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.parentPrimary),
                    ),
                    subtitle:
                        const Text('Öğretmenden alınan sınıf kodu ile ekle'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.parentPrimary),
                    onTap: _showAddChildDialog,
                  ),
                ]),
                const SizedBox(height: 20),
              ],
              _buildSettingsGroup('Bildirim Ayarları', [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active_rounded,
                      color: primaryColor),
                  title: Text('Anlık Bildirimler',
                      style: AppTextStyles.labelLarge),
                  subtitle: const Text('Duyuru ve mesaj bildirimlerini al'),
                  value: _notificationsEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: !_prefsLoaded || _savingPrefs
                      ? null
                      : (val) => _persistNotificationPrefs(
                            pushEnabled: val,
                            homeworkAlertsEnabled: _homeworkAlertsEnabled,
                          ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(Icons.assignment_turned_in_rounded,
                      color: primaryColor),
                  title: Text('Ödev & Deneme Uyarıları',
                      style: AppTextStyles.labelLarge),
                  subtitle:
                      const Text('Yaklaşan ödev ve deneme hatırlatmaları'),
                  value: _homeworkAlertsEnabled,
                  activeThumbColor: primaryColor,
                  onChanged: !_prefsLoaded || _savingPrefs
                      ? null
                      : (val) => _persistNotificationPrefs(
                            pushEnabled: _notificationsEnabled,
                            homeworkAlertsEnabled: val,
                          ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSettingsGroup('Güvenlik & Hesap', [
                if (isTeacher)
                  _buildSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Şifre Değiştir',
                    subtitle: 'Hesap şifrenizi güncelleyin',
                    onTap: _showChangePasswordDialog,
                  ),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Gizlilik Politikası & KVKK',
                  subtitle: 'Veri gizliliği ve kullanım şartları',
                  onTap: _showPrivacyPolicyDialog,
                ),
                _buildSettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Hesabımı Sil',
                  subtitle: 'Tüm kişisel verilerinizi kalıcı olarak silin',
                  onTap: _showDeleteAccountDialog,
                ),
              ]),
              const SizedBox(height: 32),
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
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

class _LinkedStudent {
  const _LinkedStudent({
    required this.id,
    required this.name,
    this.schoolNumber,
  });

  final String id;
  final String name;
  final String? schoolNumber;
}
