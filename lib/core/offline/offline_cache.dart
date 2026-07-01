import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:alara/core/offline/models/local_entities.dart';
import 'package:alara/core/offline/offline_database.dart';

/// Generic cache that stores API response JSON blobs in Isar local entities.
///
/// Each local entity (AttendanceLocal, AssessmentLocal, etc.) stores:
///   - remoteId: unique key for the record (e.g. "classes:5" or "attendance:2024-01-15:3")
///   - payloadJson: the full API JSON response
///   - updatedAt: when it was cached
///   - isDirty: whether it has pending local changes
///
/// This class abstracts those collections so services don't need to know
/// which entity type to use — they just call get/set with a cache key.
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  Isar get _db => OfflineDatabase.instance.isar;

  // ------------------------------------------------------------------
  // GENERIC GET / SET
  // ------------------------------------------------------------------

  /// Read cached JSON for [cacheKey]. Returns null if not cached.
  Future<Map<String, dynamic>?> get(String cacheKey) async {
    final entity = await _findEntity(cacheKey);
    return entity != null
        ? Map<String, dynamic>.from(jsonDecode(entity.payloadJson) as Map)
        : null;
  }

  /// Read cached list of JSON objects for [cacheKey]. Returns null if not cached.
  Future<List<Map<String, dynamic>>?> getList(String cacheKey) async {
    final entity = await _findEntity(cacheKey);
    if (entity == null) return null;
    final decoded = jsonDecode(entity.payloadJson);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    // Single object wrapped as list
    return [Map<String, dynamic>.from(decoded as Map)];
  }

  /// Write [data] to the cache under [cacheKey].
  Future<void> set(String cacheKey, dynamic data) async {
    final jsonStr = data is String ? data : jsonEncode(data);
    final now = DateTime.now();

    // Determine which collection to use based on key prefix
    final entityType = _entityTypeForKey(cacheKey);

    await _db.writeTxn(() async {
      final base = _makeBaseEntity(entityType, cacheKey, jsonStr, now);

      switch (entityType) {
        case 'class':
        case 'timetable':
          final obj = base as ClassLocal;
          await _db.classLocals.put(obj);
          break;
        case 'subject':
          final obj = base as SubjectLocal;
          await _db.subjectLocals.put(obj);
          break;
        case 'attendance':
          final obj = base as AttendanceLocal;
          await _db.attendanceLocals.put(obj);
          break;
        case 'assessment':
          final obj = base as AssessmentLocal;
          await _db.assessmentLocals.put(obj);
          break;
        case 'result':
          final obj = base as ResultLocal;
          await _db.resultLocals.put(obj);
          break;
        case 'material':
        case 'document':
          final obj = base as LearningMaterialLocal;
          await _db.learningMaterialLocals.put(obj);
          break;
        case 'announcement':
          final obj = base as AnnouncementLocal;
          await _db.announcementLocals.put(obj);
          break;
        case 'session':
        case 'academic_session':
          final obj = base as AcademicSessionLocal;
          await _db.academicSessionLocals.put(obj);
          break;
        case 'profile':
        case 'user':
          final obj = base as UserProfileLocal;
          await _db.userProfileLocals.put(obj);
          break;
        default:
          // Fallback: store in TeacherLocal as generic JSON blob
          final obj = TeacherLocal()
            ..remoteId = 'cache:$cacheKey'
            ..payloadJson = jsonStr
            ..updatedAt = now
            ..isDirty = false;
          await _db.teacherLocals.put(obj);
      }
    });
  }

  /// Remove a cached entry.
  Future<void> remove(String cacheKey) async {
    final entityType = _entityTypeForKey(cacheKey);
    final id = cacheKey;

    await _db.writeTxn(() async {
      switch (entityType) {
        case 'class':
        case 'timetable':
          await _db.classLocals.deleteByRemoteId(id);
          break;
        case 'subject':
          await _db.subjectLocals.deleteByRemoteId(id);
          break;
        case 'attendance':
          await _db.attendanceLocals.deleteByRemoteId(id);
          break;
        case 'assessment':
          await _db.assessmentLocals.deleteByRemoteId(id);
          break;
        case 'result':
          await _db.resultLocals.deleteByRemoteId(id);
          break;
        case 'material':
        case 'document':
          await _db.learningMaterialLocals.deleteByRemoteId(id);
          break;
        case 'announcement':
          await _db.announcementLocals.deleteByRemoteId(id);
          break;
        case 'session':
        case 'academic_session':
          await _db.academicSessionLocals.deleteByRemoteId(id);
          break;
        case 'profile':
        case 'user':
          await _db.userProfileLocals.deleteByRemoteId(id);
          break;
        default:
          await _db.teacherLocals.deleteByRemoteId('cache:$cacheKey');
      }
    });
  }

  /// Clear all cached data for a given entity type.
  Future<void> clear(String entityType) async {
    await _db.writeTxn(() async {
      switch (entityType) {
        case 'class':
        case 'timetable':
          await _db.classLocals.clear();
          break;
        case 'subject':
          await _db.subjectLocals.clear();
          break;
        case 'attendance':
          await _db.attendanceLocals.clear();
          break;
        case 'assessment':
          await _db.assessmentLocals.clear();
          break;
        case 'result':
          await _db.resultLocals.clear();
          break;
        case 'material':
        case 'document':
          await _db.learningMaterialLocals.clear();
          break;
        case 'announcement':
          await _db.announcementLocals.clear();
          break;
        case 'session':
        case 'academic_session':
          await _db.academicSessionLocals.clear();
          break;
        case 'profile':
        case 'user':
          await _db.userProfileLocals.clear();
          break;
      }
    });
  }

  /// Mark an entity as dirty (has pending local changes that need syncing).
  Future<void> markDirty(String cacheKey, {bool isDirty = true}) async {
    final entityType = _entityTypeForKey(cacheKey);
    final id = cacheKey;

    await _db.writeTxn(() async {
      switch (entityType) {
        case 'class':
          final e = await _db.classLocals.getByRemoteId(id);
          if (e != null) { e.isDirty = isDirty; await _db.classLocals.put(e); }
          break;
        case 'attendance':
          final e = await _db.attendanceLocals.getByRemoteId(id);
          if (e != null) { e.isDirty = isDirty; await _db.attendanceLocals.put(e); }
          break;
        case 'assessment':
          final e = await _db.assessmentLocals.getByRemoteId(id);
          if (e != null) { e.isDirty = isDirty; await _db.assessmentLocals.put(e); }
          break;
      }
    });
  }

  /// Returns true if cached data exists and is not stale.
  Future<bool> has(String cacheKey, {Duration maxAge = const Duration(hours: 1)}) async {
    final entity = await _findEntity(cacheKey);
    if (entity == null) return false;
    final age = DateTime.now().difference(entity.updatedAt);
    return age < maxAge;
  }

  // ------------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------------

  /// Derive entity type from cache key prefix.
  /// Keys are formatted as "type:rest-of-key"
  String _entityTypeForKey(String cacheKey) {
    final colon = cacheKey.indexOf(':');
    if (colon == -1) return 'generic';
    return cacheKey.substring(0, colon).toLowerCase();
  }

  dynamic _makeBaseEntity(String entityType, String cacheKey, String jsonStr, DateTime now) {
    switch (entityType) {
      case 'class':
      case 'timetable':
        return ClassLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'subject':
        return SubjectLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'attendance':
        return AttendanceLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'assessment':
        return AssessmentLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'result':
        return ResultLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'material':
      case 'document':
        return LearningMaterialLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'announcement':
        return AnnouncementLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'session':
      case 'academic_session':
        return AcademicSessionLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      case 'profile':
      case 'user':
        return UserProfileLocal()
          ..remoteId = cacheKey
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
      default:
        return TeacherLocal()
          ..remoteId = 'cache:$cacheKey'
          ..payloadJson = jsonStr
          ..updatedAt = now
          ..isDirty = false;
    }
  }

  Future<dynamic> _findEntity(String cacheKey) async {
    final entityType = _entityTypeForKey(cacheKey);
    final id = cacheKey;

    switch (entityType) {
      case 'class':
      case 'timetable':
        return await _db.classLocals.getByRemoteId(id);
      case 'subject':
        return await _db.subjectLocals.getByRemoteId(id);
      case 'attendance':
        return await _db.attendanceLocals.getByRemoteId(id);
      case 'assessment':
        return await _db.assessmentLocals.getByRemoteId(id);
      case 'result':
        return await _db.resultLocals.getByRemoteId(id);
      case 'material':
      case 'document':
        return await _db.learningMaterialLocals.getByRemoteId(id);
      case 'announcement':
        return await _db.announcementLocals.getByRemoteId(id);
      case 'session':
      case 'academic_session':
        return await _db.academicSessionLocals.getByRemoteId(id);
      case 'profile':
      case 'user':
        return await _db.userProfileLocals.getByRemoteId(id);
      default:
        return await _db.teacherLocals.getByRemoteId('cache:$cacheKey');
    }
  }
}
