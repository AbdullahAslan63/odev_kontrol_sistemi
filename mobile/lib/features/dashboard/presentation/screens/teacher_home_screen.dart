import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odev_takip/features/auth/presentation/providers/auth_providers.dart';
import 'package:odev_takip/features/homeworks/presentation/providers/homework_providers.dart';
import 'package:odev_takip/core/theme/app_colors.dart';
import 'package:odev_takip/core/theme/app_text_styles.dart';
import 'package:odev_takip/core/theme/app_sizes.dart';
import 'package:odev_takip/core/widgets/app_widgets.dart';
import 'package:odev_takip/core/widgets/eduly_logo.dart';

import '../../../../core/widgets/notification_permission_dialog.dart';

/// Öğretmen ana panel ekranı.
/// Özet kartlar, hızlı işlemler ve son aktivite listesi.
class TeacherHomeScreen extends ConsumerStatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  ConsumerState<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends ConsumerState<TeacherHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationPermissionDialog.showIfFirstTime(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar ───────────────────────────────────────────────
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
                      'Merhaba, ${user?.name.split(' ').first ?? 'Öğretmenim'} 👋',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.textOnPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTodayGreeting(),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textOnPrimaryMuted),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textOnPrimary),
                onPressed: () => context.push('/teacher/messages'),
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Özet kartlar ───────────────────────────────────────────
                const _SectionTitle('Bu Hafta', href: '/teacher/homeworks'),
                const SizedBox(height: 12),
                const _HomeworkSummaryRow(),

                // ── Hızlı işlemler ─────────────────────────────────────────
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
                      onTap: () => context.push('/teacher/classes'),
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

                // ── Son ödevler ────────────────────────────────────────────
                const SizedBox(height: 28),
                const _SectionTitle('Son Ödevler', href: '/teacher/homeworks'),
                const SizedBox(height: 12),
                const _RecentHomeworks(),

                const SizedBox(height: 32),

                // ── Çıkış ──────────────────────────────────────────────────
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(teacherAuthProvider.notifier).signOut();
                      if (context.mounted) context.go('/welcome');
                    },
                    icon: Icon(Icons.logout_rounded,
                        color: AppColors.textSecondary),
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

/// Bölüm başlığı
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.href});
  final String title;
  final String? href;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.h4),
        const Spacer(),
        TextButton(
          onPressed: href == null ? null : () => context.go(href!),
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

class _HomeworkSummaryRow extends ConsumerWidget {
  const _HomeworkSummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworks = ref.watch(teacherHomeworksStreamProvider).valueOrNull;
    final active = homeworks?.where((h) => !h.isOverdue).length ?? 0;
    final upcoming = homeworks
            ?.where((h) =>
                !h.isOverdue &&
                h.dueDate.difference(DateTime.now()).inDays <= 3)
            .length ??
        0;
    final overdue = homeworks?.where((h) => h.isOverdue).length ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Aktif Ödev',
                value: '$active',
                icon: Icons.assignment_outlined,
                color: AppColors.teacherPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Yaklaşan',
                value: '$upcoming',
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Geciken',
                value: '$overdue',
                icon: Icons.cancel_outlined,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Toplam',
                value: '${homeworks?.length ?? 0}',
                icon: Icons.assignment_rounded,
                color: AppColors.parentPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentHomeworks extends ConsumerWidget {
  const _RecentHomeworks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherHomeworksStreamProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Ödevler yüklenemedi.'),
      data: (homeworks) {
        if (homeworks.isEmpty) {
          return EmptyState(
            title: 'Henüz ödev eklenmedi',
            subtitle:
                'Yeni ödev eklemek için "Yeni Ödev" butonunu kullanın.',
            icon: Icons.assignment_rounded,
            action: () => context.push('/teacher/homeworks/new'),
            actionLabel: 'Yeni Ödev',
          );
        }
        final recent = homeworks.take(3).toList();
        return Column(
          children: [
            for (final hw in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    side: BorderSide(color: AppColors.border),
                  ),
                  title: Text(hw.title, style: AppTextStyles.h4),
                  subtitle: Text(hw.subject),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/teacher/homeworks/${hw.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Özet kart
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Hızlı işlem kutusu
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
