import '../entities/class_entity.dart';

abstract class ClassesRepository {
  /// Öğretmenin tüm sınıflarının canlı akışı
  Stream<List<ClassEntity>> getTeacherClasses(String teacherId);

  /// Tek bir sınıf bilgisini ID ile getirir
  Future<ClassEntity?> getClassById(String classId);

  /// Yeni sınıf ekleme
  Future<String> addClass(ClassEntity classEntity);

  /// Sınıf güncelleme
  Future<void> updateClass(ClassEntity classEntity);

  /// Sınıf silme
  Future<void> deleteClass(String classId);
}
