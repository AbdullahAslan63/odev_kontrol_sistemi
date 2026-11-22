import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../homeworks/presentation/providers/homework_providers.dart';
import '../../../messages/presentation/providers/messages_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../../students/presentation/widgets/parent_child_selector.dart';

/// Veli ana panel ekranı.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    final studentsAsync =
        ref.watch(parentStudentsStreamProvider(user?.uid ?? ''));
    final students = studentsAsync.valueOrNull ?? const [];
    final activeStudent =
        students.isNotEmpty ? resolveSelectedParentStudent(ref, students) : null;

    final resolvedClassName = activeStudent == null
        ? null
        : (activeStudent.className ??
            ref
                .watch(classByIdProvider(activeStudent.classId))
                .valueOrNull
                ?.name);

    final studentName = activeStudent != null
        ? (resolvedClassName != null && resolvedClassName.isNotEmpty
            ? '${activeStudent.name} ($resolvedClassName Sınıfı)'
            : activeStudent.name)
        : (studentsAsync.isLoading
            ? 'Bağlı Öğrenci Aranıyor...'
            : 'Henüz bağlı öğrenci yok');

    final schoolNo = activeStudent?.schoolNumber != null &&
            activeStudent!.schoolNumber!.isNotEmpty
        ? 'Okul No: ${activeStudent.schoolNumber}'
        : (activeStudent != null ? 'Kayıtlı Öğrenci' : 'Bağlantı Yok');

    final greetingName = activeStudent != null
        ? '${activeStudent.name} Velisi'
        : (user?.name != null && user!.name.trim().isNotEmpty
            ? user.name
            : 'Veli');

    final studentId = activeStudent?.id ?? '';
    final assignmentsAsync =
        ref.watch(studentAssignmentsStreamProvider(studentId));
    final assignments = assignmentsAsync.valueOrNull ?? [];
    final activeHomeworkCount =
        assignments.where((a) => !a.isCompleted).length;
    final completedHomeworkCount =
        assignments.where((a) => a.isCompleted).length;

    final examsAsync = ref.watch(
      studentExamsStreamProvider((studentId: studentId, teacherId: null)),
    );
    final exams = examsAsync.valueOrNull ?? [];
    final lastExam = exams.firstOrNull;
    final lastNetStr =
        lastExam != null ? lastExam.totalNet.toStringAsFixed(2) : '-';

    final goalAsync = ref.watch(
      studentGoalStreamProvider((studentId: studentId, teacherId: null)),
    );
    final goal = goalAsync.valueOrNull;
    final goalPercentStr = goal != null
        ? '%${goal.progressPercentage.clamp(0, 100).toStringAsFixed(0)}'
        : (lastExam != null && activeStudent != null && activeStudent.targetScore > 0 && lastExam.totalScore > 0
            ? '%${((lastExam.totalScore / activeStudent.targetScore) * 100).clamp(0, 100).toStringAsFixed(0)}'
            : '-');

    final teacherNoteText = (activeStudent?.teacherNote != null &&
            activeStudent!.teacherNote!.trim().isNotEmpty)
        ? activeStudent.teacherNote!.trim()
        : 'Öğretmeniniz henüz özel bir değerlendirme notu girmedi.';

    final messagesAsync = ref.watch(parentMessagesStreamProvider);
    final messages = messagesAsync.valueOrNull ?? [];
    final latestMessage = messages.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 156,
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
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 14),
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
                      'Merhaba, $greetingName 👋',
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
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () => context.push('/parent/notifications'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!studentsAsync.isLoading && activeStudent == null) ...[
                  _LinkStudentBanner(
                    onAdd: () => context.go('/parent/profile'),
                  ),
                  const SizedBox(height: 24),
                ],
                if (students.length > 1 && activeStudent != null) ...[
                  ParentChildSelectorBar(
                    students: students,
                    activeStudent: activeStudent,
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.parentSurface,
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    border: Border.all(
                      color: AppColors.parentPrimary.withValues(alpha: 0.3),
                    ),
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
                        child: const Icon(
                          Icons.face_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bağlı Öğrenci Profili',
                              style: AppTextStyles.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              studentName,
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                const _ParentSectionTitle('Özet Durumu 📊'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ParentSummaryCard(
                        label: 'Aktif Ödev',
                        value: '$activeHomeworkCount Ödev',
                        icon: Icons.assignment_rounded,
                        color: AppColors.parentPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParentSummaryCard(
                        label: 'Tamamlanan',
                        value: '$completedHomeworkCount Ödev',
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
                        value: lastNetStr,
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParentSummaryCard(
                        label: 'Hedef Başarısı',
                        value: goalPercentStr,
                        icon: Icons.track_changes_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _ParentSectionTitle('Son Öğretmen Notu 📝'),
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
                          color:
                              AppColors.teacherPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sticky_note_2_rounded,
                          color: AppColors.teacherPrimary,
                          size: 24,
                        ),
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
                              teacherNoteText,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _ParentSectionTitle('Son Duyuru & Bildirimler 🔔'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.go('/parent/messages'),
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.parentPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestMessage?.title ?? 'Duyuru Paneli',
                                style: AppTextStyles.labelLarge
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                latestMessage?.body ??
                                    'Henüz yeni bir duyuru veya mesaj bulunmuyor.',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
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
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(parentAuthProvider.notifier).signOut();
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
}

class _LinkStudentBanner extends StatelessWidget {
  const _LinkStudentBanner({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.parentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(
          color: AppColors.parentPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Öğrenci Bağlantısı Gerekli',
            style: AppTextStyles.labelLarge
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Öğretmenden aldığınız davet kodunu Profil’den girin; çocuğunuzun ödev ve denemeleri burada görünür.',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Davet Kodu ile Bağla'),
          ),
        ],
      ),
    );
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
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.h3.copyWith(color: color),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
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
