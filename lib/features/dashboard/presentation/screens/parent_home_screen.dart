import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/eduly_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/phone_auth_provider.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../homeworks/presentation/providers/homework_providers.dart';
import '../../../messages/presentation/providers/messages_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../../students/presentation/widgets/parent_child_selector.dart';

/// Veli ana panel ekranı.
/// Öğretmen paneli ile uyumlu sade ve modern Bento kart tasarımı.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    final studentsAsync =
        ref.watch(parentStudentsStreamProvider(user?.uid ?? ''));
    final students = studentsAsync.valueOrNull ?? const [];
    final activeStudent = students.isNotEmpty
        ? resolveSelectedParentStudent(ref, students)
        : null;

    final resolvedClassName = activeStudent == null
        ? null
        : (activeStudent.className ??
            ref
                .watch(classByIdProvider(activeStudent.classId))
                .valueOrNull
                ?.name);

    final studentName = activeStudent != null
        ? (resolvedClassName != null && resolvedClassName.isNotEmpty
            ? '${activeStudent.name} ($resolvedClassName)'
            : activeStudent.name)
        : (studentsAsync.isLoading
            ? 'Bağlı öğrenci aranıyor...'
            : 'Henüz bağlı öğrenci yok');

    final schoolNo = activeStudent?.schoolNumber != null &&
            activeStudent!.schoolNumber!.isNotEmpty
        ? 'No: #${activeStudent.schoolNumber}'
        : (activeStudent != null ? 'Kayıtlı' : 'Bağlantı Yok');

    final greetingName = activeStudent != null
        ? '${activeStudent.name} Velisi'
        : (user?.name != null && user!.name.trim().isNotEmpty
            ? user.name
            : 'Veli');

    final studentId = activeStudent?.id ?? '';
    final assignmentsAsync =
        ref.watch(studentAssignmentsStreamProvider(studentId));
    final assignments = assignmentsAsync.valueOrNull ?? [];
    final activeHomeworkCount = assignments.where((a) => !a.isCompleted).length;
    final completedHomeworkCount =
        assignments.where((a) => a.isCompleted).length;

    final examsAsync = ref.watch(
      studentExamsStreamProvider((studentId: studentId, teacherId: null)),
    );
    final exams = examsAsync.valueOrNull ?? [];
    final lastExam = exams.firstOrNull;
    final lastNetStr =
        lastExam != null ? lastExam.totalNet.toStringAsFixed(2) : '—';

    final goalAsync = ref.watch(
      studentGoalStreamProvider((studentId: studentId, teacherId: null)),
    );
    final goal = goalAsync.valueOrNull;
    final goalPercentStr = goal != null
        ? '%${goal.progressPercentage.clamp(0, 100).toStringAsFixed(0)}'
        : (lastExam != null &&
                activeStudent != null &&
                activeStudent.targetScore > 0 &&
                lastExam.totalScore > 0
            ? '%${((lastExam.totalScore / activeStudent.targetScore) * 100).clamp(0, 100).toStringAsFixed(0)}'
            : '—');

    final teacherNoteText = (activeStudent?.teacherNote != null &&
            activeStudent!.teacherNote!.trim().isNotEmpty)
        ? activeStudent.teacherNote!.trim()
        : 'Öğretmeniniz henüz özel bir değerlendirme notu girmedi.';

    final messagesAsync = ref.watch(parentMessagesStreamProvider);
    final messages = messagesAsync.valueOrNull ?? [];
    final latestMessage = messages.firstOrNull;

    final headerChipText = activeStudent != null
        ? '$studentName • $activeHomeworkCount bekleyen ödev'
        : 'Öğrenci bağlantısı bekleniyor';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _ParentHeroHeader(
              greetingName: greetingName,
              chipText: headerChipText,
              onNotificationTap: () => context.push('/parent/notifications'),
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
                if (!studentsAsync.isLoading && activeStudent == null) ...[
                  _LinkStudentBanner(
                    onAdd: () => context.go('/parent/profile'),
                  ),
                  const SizedBox(height: 18),
                ],
                if (students.length > 1 && activeStudent != null) ...[
                  ParentChildSelectorBar(
                    students: students,
                    activeStudent: activeStudent,
                  ),
                  const SizedBox(height: 14),
                ],
                _StudentSummaryBanner(
                  studentName: studentName,
                  badgeText: schoolNo,
                ),
                const SizedBox(height: 22),
                const _ParentSectionTitle('Genel Özet'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ParentBentoCard(
                        label: 'Aktif Ödev',
                        value: '$activeHomeworkCount',
                        icon: Icons.assignment_rounded,
                        color: AppColors.parentPrimary,
                        onTap: () => context.go('/parent/homeworks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParentBentoCard(
                        label: 'Tamamlanan Ödev',
                        value: '$completedHomeworkCount',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        onTap: () => context.go('/parent/homeworks'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ParentBentoCard(
                        label: 'Son Deneme Net',
                        value: lastNetStr,
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.accent,
                        onTap: () => context.go('/parent/exams'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParentBentoCard(
                        label: 'Hedef Başarısı',
                        value: goalPercentStr,
                        icon: Icons.track_changes_rounded,
                        color: AppColors.teacherPrimary,
                        onTap: () => context.go('/parent/exams'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _ParentSectionTitle('Öğretmen Notu'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color:
                              AppColors.teacherPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sticky_note_2_rounded,
                          color: AppColors.teacherPrimary,
                          size: 22,
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
                                  .copyWith(fontWeight: FontWeight.w700),
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
                const _ParentSectionTitle('Son Duyuru'),
                const SizedBox(height: 12),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => context.go('/parent/messages'),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
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
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.parentPrimary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: AppColors.parentPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latestMessage?.title ?? 'Duyuru Paneli',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelLarge
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latestMessage?.body ??
                                      'Henüz yeni bir duyuru veya mesaj bulunmuyor.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textSecondary),
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
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      ref.read(selectedParentStudentIdProvider.notifier).state =
                          null;
                      ref.read(phoneAuthNotifierProvider.notifier).reset();
                      await ref.read(parentAuthProvider.notifier).signOut();
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
}

class _ParentHeroHeader extends StatelessWidget {
  const _ParentHeroHeader({
    required this.greetingName,
    required this.chipText,
    required this.onNotificationTap,
  });

  final String greetingName;
  final String chipText;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            AppColors.parentPrimary,
            AppColors.parentLight,
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
                    'Merhaba, $greetingName',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Çocuğunuzun güncel eğitim durumu burada.',
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
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            chipText,
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

class _StudentSummaryBanner extends StatelessWidget {
  const _StudentSummaryBanner({
    required this.studentName,
    required this.badgeText,
  });

  final String studentName;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.parentPrimary.withValues(alpha: 0.25),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.parentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.face_rounded,
              color: AppColors.parentPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bağlı Öğrenci',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.parentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.parentPrimary,
              ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.parentPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Öğrenci Bağlantısı Gerekli',
            style:
                AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Öğretmenden aldığınız davet kodunu Profil’den girin; çocuğunuzun ödev ve denemeleri burada görünür.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
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
    return Text(
      title,
      style: AppTextStyles.h4.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ParentBentoCard extends StatelessWidget {
  const _ParentBentoCard({
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
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.h2.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
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
