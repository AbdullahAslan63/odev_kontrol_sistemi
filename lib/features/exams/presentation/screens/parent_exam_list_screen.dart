import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../../../students/presentation/widgets/parent_child_selector.dart';
import '../../domain/entities/exam_result_entity.dart';
import '../providers/exam_providers.dart';

class ParentExamListScreen extends ConsumerWidget {
  const ParentExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final parentUid = user?.uid ?? '';
    final studentsAsync = ref.watch(parentStudentsStreamProvider(parentUid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Çocuğumun Deneme Sonuçları'),
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: 'Öğrenci bilgisi şu anda yüklenemedi.',
          onRetry: () => ref.invalidate(parentStudentsStreamProvider(parentUid)),
        ),
        data: (students) {
          if (students.isEmpty) {
            return const EmptyState(
              title: 'Bağlı Öğrenci Yok',
              subtitle:
                  'Öğretmenin ürettiği davet kodunu Profil → Yeni Çocuk Ekle ile bağlayın. '
                  'Bağlantı sonrası deneme sonuçları burada görünür.',
            );
          }

          final activeStudent = resolveSelectedParentStudent(ref, students);
          final examsAsync = ref.watch(
            studentExamsStreamProvider(
              (studentId: activeStudent.id, teacherId: null),
            ),
          );

          return Column(
            children: [
              if (students.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    AppSizes.pagePadding,
                    AppSizes.pagePadding,
                    0,
                  ),
                  child: ParentChildSelectorBar(
                    students: students,
                    activeStudent: activeStudent,
                  ),
                ),
              Expanded(
                child: examsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => ErrorState(
                    message: 'Deneme sonuçları yüklenirken bir sorun oluştu.',
                    onRetry: () => ref.invalidate(
                      studentExamsStreamProvider(
                        (studentId: activeStudent.id, teacherId: null),
                      ),
                    ),
                  ),
                  data: (exams) {
                    if (exams.isEmpty) {
                      return const EmptyState(
                        title: 'Henüz Deneme Yok',
                        subtitle:
                            'Öğretmen deneme sonucu girdiğinde çocuğunuza ait sonuçlar burada listelenir.',
                      );
                    }
                    return _ExamResultsBody(exams: exams);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExamResultsBody extends StatelessWidget {
  const _ExamResultsBody({required this.exams});
  final List<ExamResultEntity> exams;

  @override
  Widget build(BuildContext context) {
    final chronologicalExams = exams.reversed.toList();
    final isSingleExam = chronologicalExams.length == 1;
    final nets = chronologicalExams.map((e) => e.totalNet).toList();
    final minNet = nets.reduce((a, b) => a < b ? a : b);
    final maxNet = nets.reduce((a, b) => a > b ? a : b);
    final chartMinY = (minNet - 10).clamp(0.0, double.infinity).floorToDouble();
    final rawMaxY = (maxNet + 10).ceilToDouble();
    final chartMaxY = rawMaxY <= chartMinY ? chartMinY + 20 : rawMaxY;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Gelişim Grafiği 📈', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: LineChart(
              LineChartData(
                minX: isSingleExam ? -0.5 : 0,
                maxX: isSingleExam
                    ? 0.5
                    : (chronologicalExams.length - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.round();
                        final label =
                            (idx >= 0 && idx < chronologicalExams.length)
                                ? chronologicalExams[idx].examName
                                : '';
                        return LineTooltipItem(
                          '$label\n${spot.y.toStringAsFixed(2)} Net',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        final idx = value.toInt();
                        if (idx >= 0 && idx < chronologicalExams.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: SizedBox(
                              width: 68,
                              child: Text(
                                chronologicalExams[idx].examName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.border),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: chronologicalExams
                        .asMap()
                        .entries
                        .map(
                          (entry) => FlSpot(
                            entry.key.toDouble(),
                            entry.value.totalNet,
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: AppColors.parentPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.parentPrimary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Geçmiş Sınavlar 📝', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          ...exams.map((exam) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(exam.examName, style: AppTextStyles.h4),
                      ),
                      Text(
                        exam.examDate.toTurkishDate(),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (exam.publisher != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Yayınevi: ${exam.publisher}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.parentPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Toplam Net',
                                style: AppTextStyles.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                exam.totalNet.toStringAsFixed(2),
                                style: AppTextStyles.h3
                                    .copyWith(color: AppColors.parentPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('Puan', style: AppTextStyles.labelSmall),
                              const SizedBox(height: 2),
                              Text(
                                exam.totalScore.toStringAsFixed(1),
                                style: AppTextStyles.h3
                                    .copyWith(color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
