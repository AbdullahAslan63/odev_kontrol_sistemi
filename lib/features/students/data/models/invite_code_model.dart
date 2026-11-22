import 'package:cloud_firestore/cloud_firestore.dart';

/// Veli davet kodu modeli (`invite_codes` koleksiyonu)
class InviteCodeModel {
  const InviteCodeModel({
    required this.code,
    required this.studentId,
    required this.teacherId,
    this.studentName,
    this.classId,
    this.className,
    required this.expiresAt,
    this.used = false,
    this.usedBy,
    this.usedAt,
    required this.createdAt,
  });

  final String code;
  final String studentId;
  final String teacherId;
  final String? studentName;
  final String? classId;
  final String? className;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !used && !isExpired;

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory InviteCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InviteCodeModel.fromMap(data, doc.id);
  }

  factory InviteCodeModel.fromMap(Map<String, dynamic> data, String id) {
    return InviteCodeModel(
      code: id,
      studentId: data['studentId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      studentName: data['studentName'] as String?,
      classId: data['classId'] as String?,
      className: data['className'] as String?,
      expiresAt: _parseDate(data['expiresAt']) ?? DateTime.now(),
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      usedAt: _parseDate(data['usedAt']),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'teacherId': teacherId,
      if (studentName != null) 'studentName': studentName,
      if (classId != null) 'classId': classId,
      if (className != null) 'className': className,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': used,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
