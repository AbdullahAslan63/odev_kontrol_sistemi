import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/student_model.dart';
import '../models/invite_code_model.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/repositories/students_repository.dart';

class StudentsRepositoryImpl implements StudentsRepository {
  StudentsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _studentsRef =>
      _firestore.collection('students');
  CollectionReference<Map<String, dynamic>> get _classesRef =>
      _firestore.collection('classes');
  CollectionReference<Map<String, dynamic>> get _inviteCodesRef =>
      _firestore.collection('invite_codes');

  @override
  Stream<List<StudentEntity>> getClassStudents(
    String classId, {
    required String teacherId,
  }) {
    if (classId.isEmpty || teacherId.isEmpty) return Stream.value([]);

    return _studentsRef
        .where('classId', isEqualTo: classId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }).handleError((_) => <StudentEntity>[]);
  }

  @override
  Stream<StudentEntity?> getStudentStream(String studentId) {
    if (studentId.isEmpty) return Stream.value(null);
    return _studentsRef.doc(studentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return StudentModel.fromFirestore(doc);
    }).handleError((_) => null);
  }

  @override
  Stream<List<StudentEntity>> getParentStudents(String parentUid) async* {
    if (parentUid.isEmpty) {
      yield const [];
      return;
    }
    try {
      await for (final snapshot in _studentsRef
          .where('parentIds', arrayContains: parentUid)
          .snapshots()) {
        final list =
            snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        yield list;
      }
    } catch (_) {
      yield const [];
    }
  }

  @override
  Future<String> addStudent(StudentEntity student) async {
    final model = StudentModel(
      id: '',
      classId: student.classId,
      className: student.className,
      teacherId: student.teacherId,
      name: student.name,
      schoolNumber: student.schoolNumber,
      phone: student.phone,
      parentIds: student.parentIds,
      targetScore: student.targetScore,
      teacherNote: student.teacherNote,
      createdAt: student.createdAt,
    );

    final docRef = await _studentsRef.add(model.toFirestore());

    try {
      await _classesRef.doc(student.classId).update({
        'studentCount': FieldValue.increment(1),
      });
    } catch (_) {}

    return docRef.id;
  }

  @override
  Future<void> updateStudent(StudentEntity student) async {
    final model = StudentModel(
      id: student.id,
      classId: student.classId,
      className: student.className,
      teacherId: student.teacherId,
      name: student.name,
      schoolNumber: student.schoolNumber,
      phone: student.phone,
      parentIds: student.parentIds,
      targetScore: student.targetScore,
      teacherNote: student.teacherNote,
      createdAt: student.createdAt,
    );

    await _studentsRef.doc(student.id).update(model.toFirestore());
  }

  @override
  Future<void> deleteStudent(String studentId, String classId) async {
    await _studentsRef.doc(studentId).delete();

    if (classId.isNotEmpty) {
      try {
        await _classesRef.doc(classId).update({
          'studentCount': FieldValue.increment(-1),
        });
      } catch (_) {}
    }
  }

  @override
  Future<InviteCodeModel> generateInviteCode({
    required String studentId,
    required String teacherId,
    String? studentName,
    String? classId,
    String? className,
  }) async {
    var code = _generateRandomCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final existing = await _inviteCodesRef.doc(code).get();
      if (!existing.exists) break;
      code = _generateRandomCode();
    }

    final now = DateTime.now();
    final expiresAt =
        now.add(const Duration(days: AppConstants.inviteCodeExpiryDays));

    final inviteModel = InviteCodeModel(
      code: code,
      studentId: studentId,
      teacherId: teacherId,
      studentName: studentName,
      classId: classId,
      className: className,
      expiresAt: expiresAt,
      createdAt: now,
    );

    await _inviteCodesRef.doc(code).set(inviteModel.toFirestore());
    return inviteModel;
  }

  @override
  Future<InviteCodeModel?> getActiveInviteCode(
    String studentId, {
    required String teacherId,
  }) async {
    if (studentId.isEmpty || teacherId.isEmpty) return null;
    try {
      final query = await _inviteCodesRef
          .where('studentId', isEqualTo: studentId)
          .where('teacherId', isEqualTo: teacherId)
          .where('used', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return null;
      final list =
          query.docs.map((d) => InviteCodeModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final model = list.first;
      return model.isExpired ? null : model;
    } catch (_) {
      return null;
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final randomPart =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'OT-$randomPart';
  }
}
