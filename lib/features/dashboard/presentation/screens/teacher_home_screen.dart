import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../homeworks/domain/entities/homework_entity.dart';
import '../../../homeworks/presentation/providers/homework_providers.dart';
import '../../../messages/presentation/providers/messages_providers.dart';

/// Öğretmen ana panel ekranı.
/// Canlı özet kartlar, hızlı işlemler ve son ödevler listesi.
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
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.teacherPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.teacherPrimary, AppColors.teacherLight],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const EdulyLogo(size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Eduly',
                          style: AppTextStyles.h4.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Merhaba, $firstName 👋',
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTodayGreeting(),
                      style:
                          AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () => context.push('/teacher/notifications'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Canlı Özet Kartları ──────────────────────────────────────
                _SectionTitle(
                  'Genel Durum',
                  onAllTap: () => context.go('/teacher/homeworks'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Aktif Ödev',
                        value: homeworksAsync.isLoading
                            ? '—'
                            : '$activeHomeworkCount',
                        icon: Icons.assignment_outlined,
                        color: AppColors.teacherPrimary,
                        onTap: () => context.go('/teacher/homeworks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
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
                      child: _SummaryCard(
                        label: 'Süresi Geçen',
                        value:
                            homeworksAsync.isLoading ? '—' : '$overdueCount',
                        icon: Icons.cancel_outlined,
                        color: AppColors.error,
                        onTap: () => context.go('/teacher/homeworks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Duyuru',
                        value: messagesAsync.isLoading
                            ? '—'
                            : '${messages.length}',
                        icon: Icons.message_outlined,
                        color: AppColors.parentPrimary,
                        onTap: () => context.push('/teacher/messages'),
                      ),
                    ),
                  ],
                ),

                // ── Hızlı İşlemler ───────────────────────────────────────────
                const SizedBox(height: 28),
                const _SectionTitle('Hızlı İşlemler'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    _QuickActionTile(
                      icon: Icons.add_circle_rounded,
                      label: 'Yeni Ödev',
                      color: AppColors.teacherPrimary,
                      onTap: () => context.push('/teacher/homeworks/new'),
                    ),
                    _QuickActionTile(
                      icon: Icons.person_add_rounded,
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
                    _QuickActionTile(
                      icon: Icons.edit_note_rounded,
                      label: 'Deneme Gir',
                      color: AppColors.accent,
                      onTap: () => context.push('/teacher/exams/create'),
                    ),
                    _QuickActionTile(
                      icon: Icons.campaign_rounded,
                      label: 'Toplu Mesaj',
                      color: AppColors.warning,
                      onTap: () => context.push('/teacher/messages/new'),
                    ),
                  ],
                ),

                // ── Son Ödevler ──────────────────────────────────────────────
                const SizedBox(height: 28),
                _SectionTitle(
                  'Son Ödevler',
                  onAllTap: () => context.go('/teacher/homeworks'),
                ),
                const SizedBox(height: 12),
                if (homeworksAsync.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (homeworks.isEmpty)
                  EmptyState(
                    title: 'Henüz ödev eklenmedi',
                    subtitle:
                        'Yeni ödev eklemek için "Yeni Ödev" butonunu kullanın.',
                    icon: Icons.assignment_rounded,
                    action: () => context.push('/teacher/homeworks/new'),
                    actionLabel: 'Yeni Ödev',
                  )
                else
                  ...homeworks.take(3).map(
                        (hw) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecentHomeworkTile(
                            homework: hw,
                            onTap: () =>
                                context.push('/teacher/homeworks/${hw.id}'),
                          ),
                        ),
                      ),

                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(teacherAuthProvider.notifier).signOut();
                      if (context.mounted) context.go('/welcome');
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.textSecondary,
                    ),
                    label: Text(
                      'Çıkış Yap',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın! Bugün harika bir gün olacak.';
    if (hour < 18) return 'İyi öğleden sonralar!';
    return 'İyi akşamlar!';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onAllTap});
  final String title;
  final VoidCallback? onAllTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.h4),
        const Spacer(),
        if (onAllTap != null)
          TextButton(
            onPressed: onAllTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Tümü',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.teacherPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: color.withAlpha(51)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentHomeworkTile extends StatelessWidget {
  const _RecentHomeworkTile({
    required this.homework,
    required this.onTap,
  });

  final HomeworkEntity homework;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                homework.subject,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.teacherPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homework.title,
                    style: AppTextStyles.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Son Teslim: ${homework.dueDate.toTurkishDate()}',
                    style: AppTextStyles.caption.copyWith(
                      color: homework.isOverdue
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
