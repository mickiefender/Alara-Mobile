import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:alara/core/offline/models/local_entities.dart';

class OfflineDatabase {
  OfflineDatabase._();

  static final OfflineDatabase instance = OfflineDatabase._();

  Isar? _isar;

  Isar get isar {
    final db = _isar;
    if (db == null) {
      throw StateError('OfflineDatabase not initialized. Call init() first.');
    }
    return db;
  }

  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        StudentLocalSchema,
        TeacherLocalSchema,
        ClassLocalSchema,
        SubjectLocalSchema,
        AttendanceLocalSchema,
        AssessmentLocalSchema,
        ResultLocalSchema,
        LearningMaterialLocalSchema,
        AnnouncementLocalSchema,
        AcademicSessionLocalSchema,
        UserProfileLocalSchema,
        SyncQueueItemSchema,
        ConflictLogSchema,
      ],
      directory: dir.path,
      name: 'alara_offline_db',
      inspector: false,
    );
  }
}
