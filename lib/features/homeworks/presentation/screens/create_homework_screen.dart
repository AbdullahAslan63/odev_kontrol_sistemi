import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/presentation/providers/class_providers.dart';
import '../../../students/presentation/providers/student_providers.dart';
import '../providers/homework_providers.dart';

class CreateHomeworkScreen extends ConsumerStatefulWidget {
  const CreateHomeworkScreen({super.key});

  @override
  ConsumerState<CreateHomeworkScreen> createState() =>
      _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends ConsumerState<CreateHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _rangeController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedClassId;
  String _selectedSubject = 'Matematik';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 2));

  final List<String> _subjects = [
    'Matematik',
    'Türkçe',
    'Fen Bilimleri',
    'Sosyal Bilgiler',
    'İngilizce',
    'Din Kültürü',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _rangeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesStreamProvider);
    final user = ref.watch(currentUserProvider);
    final homeworkState = ref.watch(homeworkNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Ödev Oluştur'),
      ),
      body: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Önce Bir Sınıf Oluşturmalısınız',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ödev verebilmek için sistemde en az bir sınıfınızın bulunması gerekir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Sınıflarıma Git',
                      onPressed: () => context.go('/teacher/classes'),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeClassId = (_selectedClassId != null &&
                  classes.any((c) => c.id == _selectedClassId))
              ? _selectedClassId!
              : classes.first.id;
          _selectedClassId = activeClassId;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: activeClassId,
                    decoration: InputDecoration(
                      labelText: 'Sınıf Seçin',
                      prefixIcon: const Icon(Icons.group_rounded),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.inputRadius),
                      ),
                    ),
                    items: classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.studentCount} Öğrenci)'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedClassId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Ders',
                      prefixIcon: const Icon(Icons.book_rounded),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.inputRadius),
                      ),
                    ),
                    items: _subjects
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSubject = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _titleController,
                    label: 'Ödev Başlığı',
                    hint: 'Örn: Bilgi Sarmal Test 32',
                    prefixIcon: Icons.assignment_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ödev başlığı zorunludur.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _sourceController,
                          label: 'Kaynak Kitap',
                          hint: 'Örn: Bilgi Sarmal',
                          prefixIcon: Icons.menu_book_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _rangeController,
                          label: 'Soru / Sayfa',
                          hint: 'Örn: 1-40. sorular',
                          prefixIcon: Icons.format_list_numbered_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Son Teslim Tarihi', style: AppTextStyles.inputLabel),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setState(
                          () => _dueDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSizes.inputRadius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.teacherPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _dueDate.toTurkishDate(),
                            style: AppTextStyles.bodyMedium,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Ödev Açıklaması (İsteğe Bağlı)',
                    hint: 'Öğrencilerin dikkat etmesi gereken noktalar...',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Ödevi Sınıfa Ata',
                    isLoading: homeworkState.isLoading,
                    icon: Icons.send_rounded,
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      final students = await ref.read(
                        classStudentsStreamProvider(
                          (classId: activeClassId, teacherId: user?.uid ?? ''),
                        ).future,
                      );
                      final studentIds = students.map((s) => s.id).toList();

                      if (studentIds.isEmpty) {
                        if (context.mounted) {
                          context.showSnackBar(
                            'Bu sınıfta henüz öğrenci yok! Ödev atayabilmek için önce öğrenci ekleyin.',
                            isError: true,
                          );
                        }
                        return;
                      }

                      final success = await ref
                          .read(homeworkNotifierProvider.notifier)
                          .createHomework(
                            teacherId: user?.uid ?? '',
                            classId: activeClassId,
                            title: _titleController.text.trim(),
                            subject: _selectedSubject,
                            sourceName: _sourceController.text.trim().isEmpty
                                ? null
                                : _sourceController.text.trim(),
                            questionRange: _rangeController.text.trim().isEmpty
                                ? null
                                : _rangeController.text.trim(),
                            description:
                                _descriptionController.text.trim().isEmpty
                                    ? null
                                    : _descriptionController.text.trim(),
                            dueDate: _dueDate,
                            studentIds: studentIds,
                          );

                      if (!context.mounted) return;
                      if (success) {
                        context.showSnackBar('Ödev başarıyla oluşturuldu!');
                        context.pop();
                      } else {
                        context.showSnackBar(
                          'Ödev oluşturulamadı. Lütfen tekrar deneyin.',
                          isError: true,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: 'Sınıflar yüklenirken bir sorun oluştu.',
          onRetry: () => ref.invalidate(teacherClassesStreamProvider),
        ),
      ),
    );
  }
}
