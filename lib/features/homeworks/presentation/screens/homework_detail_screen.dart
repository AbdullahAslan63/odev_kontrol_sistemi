import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../students/domain/entities/student_entity.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../domain/entities/homework_assignment_entity.dart';
import '../providers/homework_providers.dart';

class HomeworkDetailScreen extends ConsumerWidget {
  const HomeworkDetailScreen({super.key, required this.homeworkId});
  final String homeworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworkAsync = ref.watch(homeworkDetailProvider(homeworkId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ödev Kontrol Paneli'),
      ),
      body: homeworkAsync.when(
        data: (homework) {
          if (homework == null) {
            return EmptyState(
              title: 'Ödev Bulunamadı',
              subtitle: 'Bu ödev silinmiş veya erişilemiyor olabilir.',
              icon: Icons.assignment_late_outlined,
              action: () => ref.invalidate(homeworkDetailProvider(homeworkId)),
              actionLabel: 'Tekrar Dene',
            );
          }

          final studentsAsync = ref.watch(
            classStudentsStreamProvider(
              (classId: homework.classId, teacherId: homework.teacherId),
            ),
          );
          final assignmentsAsync = ref.watch(
            homeworkAssignmentsStreamProvider(
              (homeworkId: homeworkId, teacherId: homework.teacherId),
            ),
          );

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.teacherPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            homework.subject,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.teacherPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Son Teslim: ${homework.dueDate.toTurkishDate()}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: homework.isOverdue
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: homework.isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(homework.title, style: AppTextStyles.h3),
                    if (homework.sourceName != null ||
                        homework.questionRange != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${homework.sourceName ?? ''} ${homework.questionRange != null ? "• Soru: ${homework.questionRange}" : ""}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    if (homework.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        homework.description!,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Öğrenci Kontrol Listesi',
                        style: AppTextStyles.h4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Durum için dokunun',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: studentsAsync.when(
                  data: (students) {
                    return assignmentsAsync.when(
                      data: (assignments) {
                        if (students.isEmpty) {
                          return const Center(
                            child: Text('Sınıfta öğrenci yok.'),
                          );
                        }

                        final assignmentMap = {
                          for (final a in assignments) a.studentId: a,
                        };

                        return ListView.separated(
                          padding: const EdgeInsets.all(AppSizes.pagePadding),
                          itemCount: students.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final assignment = assignmentMap[student.id];

                            return _StudentAssignmentRow(
                              student: student,
                              assignment: assignment,
                              dueDate: homework.dueDate,
                              onStatusChange: (newStatus) async {
                                final ok = await ref
                                    .read(homeworkNotifierProvider.notifier)
                                    .upsertStatus(
                                      assignmentId: assignment?.id,
                                      homeworkId: homework.id,
                                      studentId: student.id,
                                      classId: homework.classId,
                                      teacherId: homework.teacherId,
                                      status: newStatus,
                                    );
                                if (!context.mounted) return;
                                if (!ok) {
                                  context.showSnackBar(
                                    'Ödev durumu güncellenemedi.',
                                    isError: true,
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => ErrorState(
                        message: 'Atama bilgisi yüklenemedi.',
                        onRetry: () => ref.invalidate(
                          homeworkAssignmentsStreamProvider(
                            (
                              homeworkId: homeworkId,
                              teacherId: homework.teacherId,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => ErrorState(
                    message: 'Öğrenci bilgisi yüklenemedi.',
                    onRetry: () => ref.invalidate(
                      classStudentsStreamProvider(
                        (
                          classId: homework.classId,
                          teacherId: homework.teacherId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: 'Ödev bilgisi yüklenemedi.',
          onRetry: () => ref.invalidate(homeworkDetailProvider(homeworkId)),
        ),
      ),
    );
  }
}

class _StudentAssignmentRow extends StatelessWidget {
  const _StudentAssignmentRow({
    required this.student,
    required this.assignment,
    required this.dueDate,
    required this.onStatusChange,
  });

  final StudentEntity student;
  final HomeworkAssignmentEntity? assignment;
  final DateTime dueDate;
  final void Function(String newStatus) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final rawStatus = assignment?.status ?? 'pending';
    final displayStatus =
        HomeworkStatusCalculator.calculateDisplayStatus(rawStatus, dueDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.teacherPrimary.withValues(alpha: 0.1),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.teacherPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(student.name, style: AppTextStyles.h4),
          ),
          PopupMenuButton<String>(
            initialValue: rawStatus,
            onSelected: onStatusChange,
            child: StatusBadge(status: displayStatus),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Tamamlandı'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'missed',
                child: Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Yapılmadı'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Bekliyor'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
