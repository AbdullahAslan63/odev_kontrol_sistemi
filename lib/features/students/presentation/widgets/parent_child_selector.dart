import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/student_entity.dart';
import '../providers/student_providers.dart';

/// Velinin birden fazla bağlı çocuğu varsa aktif öğrenciyi seçmesini sağlar.
StudentEntity resolveSelectedParentStudent(
  WidgetRef ref,
  List<StudentEntity> students,
) {
  final selectedId = ref.watch(selectedParentStudentIdProvider);
  if (selectedId != null) {
    for (final s in students) {
      if (s.id == selectedId) return s;
    }
  }
  return students.first;
}

class ParentChildSelectorBar extends ConsumerWidget {
  const ParentChildSelectorBar({
    super.key,
    required this.students,
    required this.activeStudent,
  });

  final List<StudentEntity> students;
  final StudentEntity activeStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (students.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: students.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final student = students[index];
          final isSelected = student.id == activeStudent.id;
          return ChoiceChip(
            label: Text(student.name),
            selected: isSelected,
            selectedColor: AppColors.parentPrimary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            onSelected: (selected) {
              if (selected) {
                ref.read(selectedParentStudentIdProvider.notifier).state =
                    student.id;
              }
            },
          );
        },
      ),
    );
  }
}
