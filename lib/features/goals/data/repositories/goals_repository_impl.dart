import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_model.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goals_repository.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _goalsRef =>
      _firestore.collection('goals');

  @override
  Stream<GoalEntity?> getStudentGoal(
    String studentId, {
    String? teacherId,
  }) {
    if (studentId.isEmpty) return Stream.value(null);
    Query<Map<String, dynamic>> query = _goalsRef
        .where('studentId', isEqualTo: studentId)
        .where('isActive', isEqualTo: true);
    if (teacherId != null && teacherId.isNotEmpty) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    return query.limit(1).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return GoalModel.fromFirestore(snapshot.docs.first);
    }).handleError((_) => null);
  }

  @override
  Future<void> setGoal(GoalEntity goal) async {
    final model = GoalModel(
      id: goal.id.isEmpty ? _goalsRef.doc().id : goal.id,
      studentId: goal.studentId,
      teacherId: goal.teacherId,
      type: goal.type,
      targetValue: goal.targetValue,
      currentValue: goal.currentValue,
      startDate: goal.startDate,
      endDate: goal.endDate,
      isActive: goal.isActive,
    );

    await _goalsRef.doc(model.id).set(model.toFirestore());
  }
}
