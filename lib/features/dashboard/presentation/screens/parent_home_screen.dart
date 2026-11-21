import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odev_takip/features/auth/presentation/providers/auth_providers.dart';
import 'package:odev_takip/core/theme/app_colors.dart';
import 'package:odev_takip/core/theme/app_text_styles.dart';
import 'package:odev_takip/core/theme/app_sizes.dart';
import 'package:odev_takip/core/widgets/matpusula_logo.dart';

import '../../../../core/widgets/notification_permission_dialog.dart';
import '../../../students/domain/entities/student_entity.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../../homeworks/presentation/providers/homework_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../goals/domain/entities/goal_entity.dart';

/// Veli ana panel ekranı.
/// Sadece öğretmene bağlı gerçek öğrenciyi gösterir — demo yok.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
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
    final studentsAsync =
        ref.watch(parentStudentsStreamProvider(user?.uid ?? ''));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.parentPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.parentPrimary, AppColors.parentLight],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const MatPusulaLogo(size: 28),
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
                      'Merhaba, ${user?.name.split(' ').first ?? 'Veli'}',
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Çocuğunuzun güncel durumu aşağıda.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () => context.push('/parent/notifications'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                studentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => _NoStudentCard(
                    message: 'Öğrenci bilgisi yüklenemedi. Tekrar deneyin.',
                    onAdd: () => context.push('/parent/profile'),
                  ),
                  data: (students) {
                    if (students.isEmpty) {
                      return _NoStudentCard(
                        message:
                            'Henüz bağlı öğrenci yok. Öğretmenden davet kodu alıp Profil’den bağlayın.',
                        onAdd: () => context.push('/parent/profile'),
                      );
                    }
                    return _LinkedStudentHome(student: students.first);
                  },
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(parentAuthProvider.notifier).signOut();
                      if (context.mounted) context.go('/welcome');
                    },
                    icon: const Icon(Icons.logout_rounded,
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
}

class _NoStudentCard extends StatelessWidget {
  const _NoStudentCard({required this.message, required this.onAdd});
  final String message;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.link_off_rounded,
              size: 40, color: AppColors.parentPrimary),
          const SizedBox(height: 12),
          Text(
            'Öğrenci Bağlantısı Gerekli',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
            ),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Davet Kodu ile Bağla'),
          ),
        ],
      ),
    );
  }
}

class _LinkedStudentHome extends ConsumerWidget {
  const _LinkedStudentHome({required this.student});
  final StudentEntity student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(studentAssignmentsStreamProvider(student.id));
    final examsAsync = ref.watch(
      studentExamsStreamProvider((studentId: student.id, teacherId: null)),
    );
    final goalAsync = ref.watch(studentGoalStreamProvider(student.id));

    final assignments = assignmentsAsync.asData?.value ?? const [];
    final exams = examsAsync.asData?.value ?? const [];
    final goal = goalAsync.asData?.value;

    final pendingCount =
        assignments.where((a) => a.status != 'completed').length;
    final completedCount =
        assignments.where((a) => a.status == 'completed').length;
    final lastNet = exams.isNotEmpty ? exams.first.totalNet : null;
    final goalPct = _goalPercent(goal);

    final schoolNo = student.schoolNumber != null
        ? 'Okul No: ${student.schoolNumber}'
        : 'Sınıf: ${student.classId}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.parentSurface,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(
                color: AppColors.parentPrimary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.parentPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bağlı Öğrenci Profili',
                        style: AppTextStyles.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${student.name} (${student.classId} Sınıfı)',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.parentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  schoolNo,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.parentPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _ParentSectionTitle('Özet Durumu'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ParentSummaryCard(
                label: 'Açık Ödev',
                value: '$pendingCount',
                icon: Icons.assignment_rounded,
                color: AppColors.parentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ParentSummaryCard(
                label: 'Tamamlanan',
                value: '$completedCount',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ParentSummaryCard(
                label: 'Son Deneme Net',
                value: lastNet != null ? lastNet.toStringAsFixed(2) : '—',
                icon: Icons.bar_chart_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ParentSummaryCard(
                label: 'Hedef Başarısı',
                value: goalPct != null ? '%$goalPct' : '—',
                icon: Icons.track_changes_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _ParentSectionTitle('Son Öğretmen Notu'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sticky_note_2_rounded,
                    color: AppColors.teacherPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Öğretmen Değerlendirmesi',
                      style: AppTextStyles.labelLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (student.teacherNote != null &&
                              student.teacherNote!.trim().isNotEmpty)
                          ? student.teacherNote!
                          : 'Henüz öğretmen notu eklenmemiş.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int? _goalPercent(GoalEntity? goal) {
    if (goal == null || goal.targetValue <= 0) return null;
    final pct = ((goal.currentValue / goal.targetValue) * 100).round();
    return pct.clamp(0, 999);
  }
}

class _ParentSectionTitle extends StatelessWidget {
  const _ParentSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.h4);
  }
}

class _ParentSummaryCard extends StatelessWidget {
  const _ParentSummaryCard({
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
