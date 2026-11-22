import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/homework_model.dart';
import '../models/homework_assignment_model.dart';
import '../../domain/entities/homework_entity.dart';
import '../../domain/entities/homework_assignment_entity.dart';
import '../../domain/repositories/homeworks_repository.dart';

class HomeworksRepositoryImpl implements HomeworksRepository {
  HomeworksRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _homeworksRef =>
      _firestore.collection('homeworks');
  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      _firestore.collection('homework_assignments');

  @override
  Stream<List<HomeworkEntity>> getTeacherHomeworks(String teacherId) {
    if (teacherId.isEmpty) return Stream.value([]);
    return _homeworksRef
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => HomeworkModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((_) => <HomeworkEntity>[]);
  }

  @override
  Stream<List<HomeworkEntity>> getClassHomeworks(
    String classId, {
    required String teacherId,
  }) {
    if (classId.isEmpty || teacherId.isEmpty) return Stream.value([]);
    return _homeworksRef
        .where('classId', isEqualTo: classId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => HomeworkModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return list;
    }).handleError((_) => <HomeworkEntity>[]);
  }

  @override
  Stream<List<HomeworkAssignmentEntity>> getHomeworkAssignments(
    String homeworkId, {
    required String teacherId,
  }) {
    if (homeworkId.isEmpty || teacherId.isEmpty) return Stream.value([]);
    return _assignmentsRef
        .where('homeworkId', isEqualTo: homeworkId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HomeworkAssignmentModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<HomeworkAssignmentEntity>> getStudentAssignments(
      String studentId) {
    if (studentId.isEmpty) return Stream.value(const []);
    return _assignmentsRef
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => HomeworkAssignmentModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Stream<HomeworkEntity?> watchHomeworkById(String homeworkId) {
    if (homeworkId.isEmpty) return Stream.value(null);
    return _homeworksRef.doc(homeworkId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return HomeworkModel.fromFirestore(doc);
    });
  }

  @override
  Future<HomeworkEntity?> getHomeworkById(String homeworkId) async {
    if (homeworkId.isEmpty) return null;
    final doc = await _homeworksRef.doc(homeworkId).get();
    if (!doc.exists || doc.data() == null) return null;
    return HomeworkModel.fromFirestore(doc);
  }

  @override
  Future<String> createHomework({
    required HomeworkEntity homework,
    required List<String> studentIds,
  }) async {
    final model = HomeworkModel(
      id: '',
      teacherId: homework.teacherId,
      classId: homework.classId,
      title: homework.title,
      subject: homework.subject,
      description: homework.description,
      sourceName: homework.sourceName,
      questionRange: homework.questionRange,
      dueDate: homework.dueDate,
      attachmentUrls: homework.attachmentUrls,
      assignedToAll: homework.assignedToAll,
      createdAt: homework.createdAt,
    );

    final docRef = _homeworksRef.doc();
    final homeworkId = docRef.id;

    // İlk batch: ödev + ilk 399 atama
    final firstChunk = studentIds.take(399).toList();
    final firstBatch = _firestore.batch();
    firstBatch.set(docRef, model.toFirestore());
    for (final studentId in firstChunk) {
      final assignmentRef = _assignmentsRef.doc();
      final assignmentModel = HomeworkAssignmentModel(
        id: assignmentRef.id,
        homeworkId: homeworkId,
        studentId: studentId,
        classId: homework.classId,
        teacherId: homework.teacherId,
        status: 'pending',
        updatedAt: DateTime.now(),
      );
      firstBatch.set(assignmentRef, assignmentModel.toFirestore());
    }
    await firstBatch.commit();

    // Kalan öğrenciler varsa 400'lük ek batch'ler
    for (var i = 399; i < studentIds.length; i += 400) {
      final chunk = studentIds.skip(i).take(400);
      final batch = _firestore.batch();
      for (final studentId in chunk) {
        final assignmentRef = _assignmentsRef.doc();
        final assignmentModel = HomeworkAssignmentModel(
          id: assignmentRef.id,
          homeworkId: homeworkId,
          studentId: studentId,
          classId: homework.classId,
          teacherId: homework.teacherId,
          status: 'pending',
          updatedAt: DateTime.now(),
        );
        batch.set(assignmentRef, assignmentModel.toFirestore());
      }
      await batch.commit();
    }

    return homeworkId;
  }

  @override
  Future<void> updateAssignmentStatus({
    required String assignmentId,
    required String status,
    String? teacherNote,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (status == 'completed') {
      updates['completedAt'] = Timestamp.fromDate(DateTime.now());
    } else {
      updates['completedAt'] = null;
    }
    if (teacherNote != null) {
      updates['teacherNote'] = teacherNote;
    }

    await _assignmentsRef.doc(assignmentId).update(updates);
  }

  @override
  Future<void> upsertAssignmentStatus({
    String? assignmentId,
    required String homeworkId,
    required String studentId,
    required String classId,
    required String teacherId,
    required String status,
    String? teacherNote,
  }) async {
    if (assignmentId != null && assignmentId.isNotEmpty) {
      await updateAssignmentStatus(
        assignmentId: assignmentId,
        status: status,
        teacherNote: teacherNote,
      );
      return;
    }

    final now = DateTime.now();
    final ref = _assignmentsRef.doc();
    final model = HomeworkAssignmentModel(
      id: ref.id,
      homeworkId: homeworkId,
      studentId: studentId,
      classId: classId,
      teacherId: teacherId,
      status: status,
      completedAt: status == 'completed' ? now : null,
      teacherNote: teacherNote,
      updatedAt: now,
    );
    await ref.set(model.toFirestore());
  }

  @override
  Future<void> deleteHomework(
    String homeworkId, {
    required String teacherId,
  }) async {
    final assignments = await _assignmentsRef
        .where('homeworkId', isEqualTo: homeworkId)
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final refs = <DocumentReference<Map<String, dynamic>>>[
      ...assignments.docs.map((d) => d.reference),
      _homeworksRef.doc(homeworkId),
    ];

    for (var i = 0; i < refs.length; i += 400) {
      final chunk = refs.skip(i).take(400);
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
