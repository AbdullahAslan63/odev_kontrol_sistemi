import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

class MessagesRepository {
  final FirebaseFirestore _firestore;

  MessagesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Toplu veya bireysel mesaj. Sahiplik ve bildirimler `sendTeacherMessage` ile yazılır.
  Future<void> sendMessage({
    required String teacherId,
    String? teacherName,
    String? classId,
    String? className,
    String? targetStudentId,
    required String title,
    required String body,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendTeacherMessage');
      await callable.call<Map<String, dynamic>>({
        'teacherId': teacherId,
        if (teacherName != null && teacherName.isNotEmpty)
          'teacherName': teacherName,
        if (classId != null && classId.isNotEmpty) 'classId': classId,
        if (className != null && className.isNotEmpty) 'className': className,
        if (targetStudentId != null && targetStudentId.isNotEmpty)
          'targetStudentId': targetStudentId,
        'title': title,
        'body': body,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Mesaj gönderilemedi.');
    }
  }

  /// Öğretmenin gönderdiği tüm mesajlar akışı
  Stream<List<MessageEntity>> getTeacherMessagesStream(String teacherId) {
    return _firestore
        .collection('messages')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  /// Velinin aldığı tüm öğretmen mesajları akışı
  Stream<List<MessageEntity>> getParentMessagesStream(String parentId) {
    return _firestore
        .collection('messages')
        .where('parentIds', arrayContains: parentId)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }
}
