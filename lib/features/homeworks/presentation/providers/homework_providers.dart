import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/homeworks_repository_impl.dart';
import '../../domain/entities/homework_entity.dart';
import '../../domain/entities/homework_assignment_entity.dart';
import '../../domain/repositories/homeworks_repository.dart';

final homeworksRepositoryProvider = Provider<HomeworksRepository>((ref) {
  return HomeworksRepositoryImpl();
});

/// Öğretmenin tüm ödevlerinin canlı akışı
final teacherHomeworksStreamProvider =
    StreamProvider<List<HomeworkEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isTeacher) return Stream.value([]);
  return ref.watch(homeworksRepositoryProvider).getTeacherHomeworks(user.uid);
});

/// Bir ödeve ait öğrenci durumlarının akışı (teacherId zorunlu)
final homeworkAssignmentsStreamProvider = StreamProvider.autoDispose.family<
    List<HomeworkAssignmentEntity>,
    ({String homeworkId, String teacherId})>((ref, params) {
  final teacherId = params.teacherId.isNotEmpty
      ? params.teacherId
      : (FirebaseAuth.instance.currentUser?.uid ?? '');
  return ref.watch(homeworksRepositoryProvider).getHomeworkAssignments(
        params.homeworkId,
        teacherId: teacherId,
      );
});

/// Bir öğrenciye ait tüm ödev atamalarının canlı akışı (Veli paneli için)
final studentAssignmentsStreamProvider = StreamProvider.autoDispose
    .family<List<HomeworkAssignmentEntity>, String>((ref, studentId) {
  return ref
      .watch(homeworksRepositoryProvider)
      .getStudentAssignments(studentId);
});

/// Tek bir ödevin detaylarını canlı getiren provider
final homeworkDetailProvider =
    StreamProvider.autoDispose.family<HomeworkEntity?, String>(
        (ref, homeworkId) {
  return ref.watch(homeworksRepositoryProvider).watchHomeworkById(homeworkId);
});

/// Ödev oluşturma ve durum güncelleme Notifier'ı
class HomeworkNotifier extends StateNotifier<AsyncValue<void>> {
  HomeworkNotifier(this._repo) : super(const AsyncValue.data(null));

  final HomeworksRepository _repo;

  Future<bool> createHomework({
    required String teacherId,
    required String classId,
    required String title,
    required String subject,
    String? description,
    String? sourceName,
    String? questionRange,
    required DateTime dueDate,
    required List<String> studentIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      final homework = HomeworkEntity(
        id: '',
        teacherId: teacherId,
        classId: classId,
        title: title,
        subject: subject,
        description: description,
        sourceName: sourceName,
        questionRange: questionRange,
        dueDate: dueDate,
        createdAt: DateTime.now(),
      );
      await _repo.createHomework(homework: homework, studentIds: studentIds);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStatus({
    required String assignmentId,
    required String status,
    String? teacherNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateAssignmentStatus(
        assignmentId: assignmentId,
        status: status,
        teacherNote: teacherNote,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> upsertStatus({
    String? assignmentId,
    required String homeworkId,
    required String studentId,
    required String classId,
    required String teacherId,
    required String status,
    String? teacherNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.upsertAssignmentStatus(
        assignmentId: assignmentId,
        homeworkId: homeworkId,
        studentId: studentId,
        classId: classId,
        teacherId: teacherId,
        status: status,
        teacherNote: teacherNote,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteHomework(
    String homeworkId, {
    required String teacherId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteHomework(homeworkId, teacherId: teacherId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final homeworkNotifierProvider =
    StateNotifierProvider<HomeworkNotifier, AsyncValue<void>>((ref) {
  return HomeworkNotifier(ref.watch(homeworksRepositoryProvider));
});
