import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/phone_auth_provider.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../homeworks/domain/entities/homework_entity.dart';
import '../../../homeworks/presentation/providers/homework_providers.dart';
import '../../../messages/presentation/providers/messages_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';

/// Öğretmen ana panel ekranı.
/// Sade, modern ve uyumlu Bento kart tasarımı.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final homeworksAsync = ref.watch(teacherHomeworksStreamProvider);
    final classesAsync = ref.watch(teacherClassesStreamProvider);
    final messagesAsync = ref.watch(teacherMessagesStreamProvider);

    final homeworks = homeworksAsync.valueOrNull ?? const <HomeworkEntity>[];
    final classes = classesAsync.valueOrNull ?? const [];
    final messages = messagesAsync.valueOrNull ?? const [];

    final activeHomeworkCount = homeworks.where((h) => !h.isOverdue).length;
    final upcomingCount = homeworks
        .where((h) => !h.isOverdue && h.dueDate.daysUntil() <= 3)
        .length;
    final overdueCount = homeworks.where((h) => h.isOverdue).length;

    final firstName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim().split(' ').first
        : 'Öğretmenim';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _TeacherHeroHeader(
              firstName: firstName,
              greeting: _getTodayGreeting(),
              summaryChipText: classesAsync.isLoading
                  ? 'Sınıflar yükleniyor...'
                  : '${classes.length} sınıf • $activeHomeworkCount aktif ödev',
              onNotificationTap: () => context.push('/teacher/notifications'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              20,
              AppSizes.pagePadding,
              28,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(
                  title: 'Genel Durum',
                  actionLabel: 'Tümü',
                  onActionTap: () => context.go('/teacher/homeworks'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BentoMetricCard(
                        label: 'Aktif Ödev',
                        value: homeworksAsync.isLoading
                            ? '—'
                            : '$activeHomeworkCount',
                        icon: Icons.assignment_rounded,
                        color: AppColors.teacherPrimary,
                        onTap: () => context.go('/teacher/homeworks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoMetricCard(
                        label: 'Yaklaşan (3 Gün)',
                        value:
                            homeworksAsync.isLoading ? '—' : '$upcomingCount',
                        icon: Icons.schedule_rounded,
                        color: AppColors.warning,
                        onTap: () => context.go('/teacher/homeworks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BentoMetricCard(
                        label: 'Süresi Geçen',
                        value: homeworksAsync.isLoading ? '—' : '$overdueCount',
                        icon: Icons.error_outline_rounded,
                        color: AppColors.error,
                        onTap: () => context.go('/teacher/homeworks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoMetricCard(
                        label: 'Duyurular',
                        value: messagesAsync.isLoading
                            ? '—'
                            : '${messages.length}',
                        icon: Icons.campaign_rounded,
                        color: AppColors.parentPrimary,
                        onTap: () => context.push('/teacher/messages'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Hızlı İşlemler'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _QuickActionDockItem(
                        icon: Icons.add_task_rounded,
                        label: 'Yeni Ödev',
                        color: AppColors.teacherPrimary,
                        onTap: () => context.push('/teacher/homeworks/new'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionDockItem(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Öğrenci Ekle',
                        color: AppColors.parentPrimary,
                        onTap: () {
                          if (classes.length == 1) {
                            context.push('/teacher/classes/${classes.first.id}');
                          } else {
                            context.go('/teacher/classes');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionDockItem(
                        icon: Icons.analytics_rounded,
                        label: 'Deneme Gir',
                        color: AppColors.accent,
                        onTap: () => context.push('/teacher/exams/create'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionDockItem(
                        icon: Icons.send_rounded,
                        label: 'Toplu Mesaj',
                        color: AppColors.info,
                        onTap: () => context.push('/teacher/messages/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Son Ödevler',
                  actionLabel: 'Tümünü Gör',
                  onActionTap: () => context.go('/teacher/homeworks'),
                ),
                const SizedBox(height: 12),
                if (homeworksAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (homeworks.isEmpty)
                  _EmptyHomeworksCard(
                    onCreateTap: () => context.push('/teacher/homeworks/new'),
                  )
                else
                  ...homeworks.take(3).map(
                        (hw) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ModernHomeworkTile(
                            homework: hw,
                            onTap: () =>
                                context.push('/teacher/homeworks/${hw.id}'),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      ref.read(selectedParentStudentIdProvider.notifier).state =
                          null;
                      ref.read(phoneAuthNotifierProvider.notifier).reset();
                      await ref.read(teacherAuthProvider.notifier).signOut();
                      if (context.mounted) context.go('/welcome');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      'Çıkış Yap',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın, verimli bir gün dileriz.';
    if (hour < 18) return 'İyi günler, sınıf durumunuz hazır.';
    return 'İyi akşamlar, günlük özetiniz hazır.';
  }
}

class _TeacherHeroHeader extends StatelessWidget {
  const _TeacherHeroHeader({
    required this.firstName,
    required this.greeting,
    required this.summaryChipText,
    required this.onNotificationTap,
  });

  final String firstName;
  final String greeting;
  final String summaryChipText;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4338CA),
            AppColors.teacherPrimary,
            AppColors.teacherLight,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -28,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const EdulyLogo(size: 22),
                            const SizedBox(width: 7),
                            Text(
                              'Eduly',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onNotificationTap,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Merhaba, $firstName',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greeting,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_graph_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            summaryChipText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onActionTap != null && actionLabel != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                actionLabel!,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.teacherPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BentoMetricCard extends StatelessWidget {
  const _BentoMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.75),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: AppTextStyles.h2.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionDockItem extends StatelessWidget {
  const _QuickActionDockItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.75),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernHomeworkTile extends StatelessWidget {
  const _ModernHomeworkTile({
    required this.homework,
    required this.onTap,
  });

  final HomeworkEntity homework;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        homework.isOverdue ? AppColors.error : AppColors.teacherPrimary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.75),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teacherPrimary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            homework.subject,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.teacherPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            homework.title,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: homework.isOverdue
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Son Teslim: ${homework.dueDate.toTurkishDate()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: homework.isOverdue
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: homework.isOverdue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHomeworksCard extends StatelessWidget {
  const _EmptyHomeworksCard({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.teacherPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.post_add_rounded,
              color: AppColors.teacherPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Henüz ödev eklenmedi',
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Sınıfınıza ilk ödevi saniyeler içinde atayın.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreateTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teacherPrimary,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Yeni Ödev Oluştur'),
          ),
        ],
      ),
    );
  }
}
