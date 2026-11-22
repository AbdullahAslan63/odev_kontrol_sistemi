import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../students/domain/entities/student_entity.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../providers/class_providers.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final teacherId = user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final classAsync = ref.watch(classByIdProvider(widget.classId));
    final className = classAsync.valueOrNull?.name;
    final studentsAsync = ref.watch(
      classStudentsStreamProvider(
        (classId: widget.classId, teacherId: teacherId),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          className != null && className.isNotEmpty
              ? '$className • Öğrenciler'
              : 'Sınıf Detayı & Öğrenciler',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Öğrenci Ekle',
            onPressed: () =>
                _showAddStudentDialog(context, teacherId, className),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppTextField(
              controller: _searchController,
              hint: 'Öğrenci adı veya okul numarası ara...',
              prefixIcon: Icons.search_rounded,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                final filtered = students.where((s) {
                  final query = _searchQuery.toLowerCase();
                  return s.name.toLowerCase().contains(query) ||
                      (s.schoolNumber?.contains(query) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    title: _searchQuery.isEmpty
                        ? 'Henüz Öğrenci Yok'
                        : 'Öğrenci Bulunamadı',
                    subtitle: _searchQuery.isEmpty
                        ? 'Bu sınıfa ilk öğrenciyi eklemek için aşağıdaki butona tıklayın.'
                        : 'Arama kriterlerinize uyan öğrenci bulunamadı.',
                    icon: Icons.person_off_rounded,
                    action: () =>
                        _showAddStudentDialog(context, teacherId, className),
                    actionLabel: 'Öğrenci Ekle',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.pagePadding),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = filtered[index];
                    return _StudentCard(
                      student: student,
                      onTap: () =>
                          context.push('/teacher/students/${student.id}'),
                      onDelete: () => _confirmDeleteStudent(context, student),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text(
                  'Öğrenci bilgisi yüklenemedi. Lütfen tekrar giriş yapın.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentDialog(context, teacherId, className),
        backgroundColor: AppColors.teacherPrimary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label:
            const Text('Öğrenci Ekle', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showAddStudentDialog(
    BuildContext context,
    String teacherId,
    String? className,
  ) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          title: const Text('Yeni Öğrenci Ekle'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Öğrenci Ad Soyad',
                    hint: 'Örn: Ahmet Yılmaz',
                    prefixIcon: Icons.person_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Öğrenci adı zorunludur.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: numberController,
                    label: 'Okul Numarası (İsteğe Bağlı)',
                    hint: 'Örn: 104',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: noteController,
                    label: 'Öğretmen Notu (İsteğe Bağlı)',
                    hint: 'Örn: Problemler konusunu tekrar etmeli.',
                    prefixIcon: Icons.note_alt_rounded,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teacherPrimary,
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final success = await ref
                          .read(studentNotifierProvider.notifier)
                          .addStudent(
                            classId: widget.classId,
                            className: className,
                            teacherId: teacherId,
                            name: nameController.text.trim(),
                            schoolNumber: numberController.text.trim().isEmpty
                                ? null
                                : numberController.text.trim(),
                            teacherNote: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      if (success) {
                        context.showSnackBar('Öğrenci başarıyla eklendi!');
                      } else {
                        context.showSnackBar(
                          'Öğrenci eklenemedi. Lütfen tekrar deneyin.',
                          isError: true,
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      numberController.dispose();
      noteController.dispose();
    });
  }

  void _confirmDeleteStudent(BuildContext context, StudentEntity student) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${student.name} Silinsin mi?'),
        content: const Text(
          'Bu öğrenciyi ve ilgili verileri silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(studentNotifierProvider.notifier)
                  .deleteStudent(student.id, widget.classId);
              if (!context.mounted) return;
              if (ok) {
                context.showSnackBar('${student.name} silindi.');
              } else {
                context.showSnackBar(
                  'Öğrenci silinemedi. Lütfen tekrar deneyin.',
                  isError: true,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onDelete,
  });

  final StudentEntity student;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    AppColors.teacherPrimary.withValues(alpha: 0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.teacherPrimary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.name,
                            style: AppTextStyles.h4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (student.schoolNumber != null &&
                            student.schoolNumber!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#${student.schoolNumber}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          student.hasParent
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: student.hasParent
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            student.hasParent
                                ? 'Veli Bağlı'
                                : 'Veli Bekliyor (Davet Kodu Gerekli)',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: student.hasParent
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                tooltip: 'Öğrenciyi Sil',
                onPressed: onDelete,
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
