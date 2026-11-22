import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

class MessagesRepository {
  MessagesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Toplu veya Bireysel Mesaj Gönderimi — alıcı veli sayısını döndürür
  Future<int> sendMessage({
    required String teacherId,
    String? teacherName,
    String? classId,
    String? className,
    String? targetStudentId,
    required String title,
    required String body,
  }) async {
    final targetParentIds = <String>[];
    final targetStudentIds = <String>[];

    if (targetStudentId != null) {
      final studentDoc =
          await _firestore.collection('students').doc(targetStudentId).get();
      if (studentDoc.exists) {
        final data = studentDoc.data() ?? {};
        targetStudentIds.add(targetStudentId);
        final parents = List<String>.from(data['parentIds'] as List? ?? []);
        targetParentIds.addAll(parents);
      }
    } else if (classId != null) {
      final studentsSnap = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      for (final doc in studentsSnap.docs) {
        targetStudentIds.add(doc.id);
        final parents =
            List<String>.from(doc.data()['parentIds'] as List? ?? []);
        targetParentIds.addAll(parents);
      }
    } else {
      final studentsSnap = await _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      for (final doc in studentsSnap.docs) {
        targetStudentIds.add(doc.id);
        final parents =
            List<String>.from(doc.data()['parentIds'] as List? ?? []);
        targetParentIds.addAll(parents);
      }
    }

    final uniqueParentIds = targetParentIds.toSet().toList();
    final messageRef = _firestore.collection('messages').doc();

    final messageModel = MessageModel(
      id: messageRef.id,
      teacherId: teacherId,
      teacherName: teacherName,
      parentIds: uniqueParentIds,
      studentIds: targetStudentIds,
      classId: classId,
      className: className,
      title: title,
      body: body,
      type: targetStudentId != null ? MessageType.individual : MessageType.bulk,
      createdAt: DateTime.now(),
    );

    // Mesaj + ilk 399 bildirim atomik batch içinde
    final firstChunk = uniqueParentIds.take(399).toList();
    final firstBatch = _firestore.batch();
    firstBatch.set(messageRef, messageModel.toFirestore());
    for (final parentId in firstChunk) {
      final notifRef = _firestore.collection('notifications').doc();
      firstBatch.set(notifRef, {
        'userId': parentId,
        'teacherId': teacherId,
        'title': '📩 $title',
        'body': body,
        'type': 'message',
        'data': {'messageId': messageRef.id},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await firstBatch.commit();

    // Veli sayısı 399'u aşarsa ek batch'ler
    for (var i = 399; i < uniqueParentIds.length; i += 400) {
      final chunk = uniqueParentIds.skip(i).take(400);
      final batch = _firestore.batch();
      for (final parentId in chunk) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': parentId,
          'teacherId': teacherId,
          'title': '📩 $title',
          'body': body,
          'type': 'message',
          'data': {'messageId': messageRef.id},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    return uniqueParentIds.length;
  }

  /// Öğretmenin gönderdiği tüm mesajlar akışı
  Stream<List<MessageEntity>> getTeacherMessagesStream(String teacherId) {
    if (teacherId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('messages')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Velinin aldığı tüm öğretmen mesajları akışı
  Stream<List<MessageEntity>> getParentMessagesStream(String parentId) {
    if (parentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('messages')
        .where('parentIds', arrayContains: parentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
