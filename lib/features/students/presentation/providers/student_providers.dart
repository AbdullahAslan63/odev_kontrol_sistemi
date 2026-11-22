import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invite_code_model.dart';
import '../../data/repositories/students_repository_impl.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/repositories/students_repository.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  return StudentsRepositoryImpl();
});

/// Velinin çoklu çocuk arasında seçtiği aktif öğrenci ID'si
final selectedParentStudentIdProvider = StateProvider<String?>((ref) => null);

/// Sınıfa göre öğrencilerin canlı akışı
/// Family parametresi: (classId, teacherId) record
final classStudentsStreamProvider = StreamProvider.autoDispose.family<
    List<StudentEntity>, ({String classId, String teacherId})>((ref, params) {
  final teacherId = params.teacherId.isNotEmpty
      ? params.teacherId
      : (FirebaseAuth.instance.currentUser?.uid ?? '');
  if (teacherId.isEmpty || params.classId.isEmpty) {
    return Stream.value(const <StudentEntity>[]);
  }
  return ref
      .watch(studentsRepositoryProvider)
      .getClassStudents(params.classId, teacherId: teacherId);
});

/// Tek öğrenci akışı
final studentStreamProvider = StreamProvider.autoDispose
    .family<StudentEntity?, String>((ref, studentId) {
  return ref.watch(studentsRepositoryProvider).getStudentStream(studentId);
});

/// Veliye bağlı öğrencilerin canlı akışı
final parentStudentsStreamProvider = StreamProvider.autoDispose
    .family<List<StudentEntity>, String>((ref, parentUid) {
  if (parentUid.isEmpty) return Stream.value(const <StudentEntity>[]);
  return ref.watch(studentsRepositoryProvider).getParentStudents(parentUid);
});

/// Öğrencinin aktif davet kodu getirme provider'ı
final activeInviteCodeProvider = FutureProvider.autoDispose
    .family<InviteCodeModel?, ({String studentId, String teacherId})>(
        (ref, params) {
  final teacherId = params.teacherId.isNotEmpty
      ? params.teacherId
      : (FirebaseAuth.instance.currentUser?.uid ?? '');
  if (params.studentId.isEmpty || teacherId.isEmpty) return Future.value(null);
  return ref
      .watch(studentsRepositoryProvider)
      .getActiveInviteCode(params.studentId, teacherId: teacherId);
});

/// Öğrenci ekleme/silme ve Davet Kodu Üretme Notifier'ı
class StudentNotifier extends StateNotifier<AsyncValue<void>> {
  StudentNotifier(this._repo) : super(const AsyncValue.data(null));

  final StudentsRepository _repo;

  Future<bool> addStudent({
    required String classId,
    String? className,
    required String teacherId,
    required String name,
    String? schoolNumber,
    String? phone,
    double targetScore = 500.0,
    String? teacherNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      final student = StudentEntity(
        id: '',
        classId: classId,
        className: className,
        teacherId: teacherId,
        name: name,
        schoolNumber: schoolNumber,
        phone: phone,
        targetScore: targetScore,
        teacherNote: teacherNote,
        createdAt: DateTime.now(),
      );
      await _repo.addStudent(student);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteStudent(String studentId, String classId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteStudent(studentId, classId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<InviteCodeModel?> generateInviteCode({
    required String studentId,
    required String teacherId,
    String? studentName,
    String? classId,
    String? className,
  }) async {
    state = const AsyncValue.loading();
    try {
      final inviteCode = await _repo.generateInviteCode(
        studentId: studentId,
        teacherId: teacherId,
        studentName: studentName,
        classId: classId,
        className: className,
      );
      state = const AsyncValue.data(null);
      return inviteCode;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final studentNotifierProvider =
    StateNotifierProvider<StudentNotifier, AsyncValue<void>>((ref) {
  return StudentNotifier(ref.watch(studentsRepositoryProvider));
});
