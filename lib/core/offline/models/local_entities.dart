import 'dart:convert';
import 'package:isar/isar.dart';

part 'local_entities.g.dart';

enum SyncOperationType { create, update, delete }

enum SyncItemStatus { pending, syncing, synced, failed, localOnly }

@collection
class StudentLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class TeacherLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class ClassLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class SubjectLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class AttendanceLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class AssessmentLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class ResultLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class LearningMaterialLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class AnnouncementLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class AcademicSessionLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class UserProfileLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String remoteId;

  late String payloadJson;
  late DateTime updatedAt;
  DateTime? lastSyncedAt;
  bool isDirty = false;
}

@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;

  @Index()
  late String entityType;

  @Index()
  late String entityId;

  @Enumerated(EnumType.name)
  late SyncOperationType operationType;

  late String endpoint;
  String method = 'POST';
  late String payloadJson;

  @Enumerated(EnumType.name)
  SyncItemStatus status = SyncItemStatus.pending;

  int retryCount = 0;
  int maxRetries = 8;
  DateTime? nextRetryAt;
  String? lastError;

  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? syncedAt;
}

@collection
class ConflictLog {
  Id id = Isar.autoIncrement;

  late String entityType;
  late String entityId;
  late String localPayloadJson;
  late String serverPayloadJson;
  late DateTime localUpdatedAt;
  late DateTime serverUpdatedAt;
  late String resolution;
  late DateTime createdAt;
}

Map<String, dynamic> decodePayload(String json) =>
    Map<String, dynamic>.from(jsonDecode(json) as Map);

String encodePayload(Map<String, dynamic> payload) => jsonEncode(payload);
