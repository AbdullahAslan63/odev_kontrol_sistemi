import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';

class AnalyticsGraphScreen extends ConsumerWidget {
  const AnalyticsGraphScreen({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final teacherId = user?.isTeacher == true ? user?.uid : null;
    final studentAsync = ref.watch(studentStreamProvider(studentId));
    final examsAsync = ref.watch(
      studentExamsStreamProvider((studentId: studentId, teacherId: teacherId)),
    );
    final goalAsync = ref.watch(
      studentGoalStreamProvider((studentId: studentId, teacherId: teacherId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gelişim & Net Analizi'),
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Öğrenci bulunamadı.'));
          }

          return examsAsync.when(
            data: (exams) {
              if (exams.isEmpty) {
                return EmptyState(
                  title: 'Henüz Deneme Kaydı Yok',
                  subtitle:
                      '${student.name} için henüz girilmiş deneme sınavı bulunmuyor.',
                  icon: Icons.show_chart_rounded,
                );
              }

              final chronologicalExams = exams.reversed.toList();
              final isSingleExam = chronologicalExams.length == 1;
              final nets = chronologicalExams.map((e) => e.totalNet).toList();
              final minNet = nets.reduce((a, b) => a < b ? a : b);
              final maxNet = nets.reduce((a, b) => a > b ? a : b);
              final chartMinY =
                  (minNet - 10).clamp(0.0, double.infinity).floorToDouble();
              final rawMaxY = (maxNet + 10).ceilToDouble();
              final chartMaxY = rawMaxY <= chartMinY ? chartMinY + 20 : rawMaxY;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Öğrenci Başlık Kartı ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.teacherPrimary.withValues(alpha: 0.1),
                            child: Text(
                              student.name.isNotEmpty
                                  ? student.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.h3
                                  .copyWith(color: AppColors.teacherPrimary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.name, style: AppTextStyles.h3),
                                Text(
                                  student.schoolNumber != null &&
                                          student.schoolNumber!.isNotEmpty
                                      ? 'Okul No: #${student.schoolNumber}'
                                      : 'Okul No Belirtilmemiş',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Hedef İlerleme Kartı ─────────────────────────────────
                    goalAsync.when(
                      data: (goal) {
                        final latestExam = exams.first;
                        final isNetGoal = goal?.type == 'net';
                        final target = goal?.targetValue ?? student.targetScore;
                        final current = isNetGoal
                            ? latestExam.totalNet
                            : latestExam.totalScore;
                        final unitLabel = isNetGoal ? 'Net' : 'Puan';
                        final remaining = (target - current).clamp(0, target);
                        final progress = target > 0
                            ? (current / target).clamp(0.0, 1.0)
                            : 0.0;

                        if (!isNetGoal && latestExam.totalScore <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppSizes.cardRadius),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Hedef Takibi', style: AppTextStyles.h4),
                                  Text(
                                    '${current.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} $unitLabel',
                                    style: AppTextStyles.h4
                                        .copyWith(color: AppColors.accent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white,
                                color: AppColors.accent,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                remaining > 0
                                    ? 'Hedefe Kalan: ${remaining.toStringAsFixed(1)} $unitLabel'
                                    : 'Tebrikler! Hedefe ulaşıldı!',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 20),
                    Text('Net İlerleme Grafiği', style: AppTextStyles.h3),
                    const SizedBox(height: 12),

                    Container(
                      height: 240,
                      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
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
                                  final label = (idx >= 0 &&
                                          idx < chronologicalExams.length)
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
                                  if (idx >= 0 &&
                                      idx < chronologicalExams.length) {
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
                              color: AppColors.teacherPrimary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.teacherPrimary
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Son Sınav Ders Dağılımı', style: AppTextStyles.h3),
                    const SizedBox(height: 12),

                    ...exams.first.scores.entries.map((e) {
                      final subject = e.key;
                      final score = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSizes.cardRadius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(subject, style: AppTextStyles.labelLarge),
                            Text(
                              '${score.correct} D / ${score.wrong} Y → ${score.net.toStringAsFixed(2)} Net',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.teacherPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => ErrorState(
              message: 'Sınavlar şu anda yüklenemedi.',
              onRetry: () => ref.invalidate(
                studentExamsStreamProvider(
                  (studentId: studentId, teacherId: teacherId),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: 'Öğrenci bilgisi şu anda yüklenemedi.',
          onRetry: () => ref.invalidate(studentStreamProvider(studentId)),
        ),
      ),
    );
  }
}
