import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:workmanager/workmanager.dart';
import 'package:alara/core/offline/models/local_entities.dart';
import 'package:alara/core/offline/offline_database.dart';
import 'package:alara/core/offline/sync/sync_status.dart';
import 'package:alara/core/services/auth_service.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final AuthService _authService = AuthService();

  SyncUiState _state = SyncUiState.localStorage;
  SyncUiState get state => _state;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  bool _initialized = false;
  bool _isSyncing = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _refreshPendingCount();
    await _initBackgroundSync();
  }

  Future<void> _initBackgroundSync() async {
    try {
      await Workmanager().initialize(_backgroundSyncDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'alara-offline-sync-periodic',
        'alaraSyncTask',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // Workmanager is unsupported on this platform (e.g. macOS desktop).
      // Background sync will only run when the app is foregrounded.
    }
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final db = OfflineDatabase.instance.isar;
    final now = DateTime.now();

    await db.writeTxn(() async {
      final item = SyncQueueItem()
        ..entityType = entityType
        ..entityId = entityId
        ..operationType = operationType
        ..endpoint = endpoint
        ..method = method.toUpperCase()
        ..payloadJson = jsonEncode(payload)
        ..status = SyncItemStatus.pending
        ..createdAt = now
        ..updatedAt = now;
      await db.syncQueueItems.put(item);
    });

    await _refreshPendingCount();
    _state = SyncUiState.pendingSync;
    notifyListeners();
  }

  Future<void> triggerSyncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _state = SyncUiState.syncing;
    notifyListeners();

    try {
      final db = OfflineDatabase.instance.isar;
      final now = DateTime.now();

      // Isar filter chain: status filter → sort → findAll
      final pendingItems = await db.syncQueueItems
          .filter()
          .statusEqualTo(SyncItemStatus.pending)
          .sortByCreatedAt()
          .findAll();

      final failedNoRetryItems = await db.syncQueueItems
          .filter()
          .statusEqualTo(SyncItemStatus.failed)
          .nextRetryAtIsNull()
          .sortByCreatedAt()
          .findAll();

      final failedRetryDueItems = await db.syncQueueItems
          .filter()
          .statusEqualTo(SyncItemStatus.failed)
          .nextRetryAtLessThan(now)
          .sortByCreatedAt()
          .findAll();

      final items = <SyncQueueItem>[
        ...pendingItems,
        ...failedNoRetryItems,
        ...failedRetryDueItems,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final item in items) {
        await _syncItem(item);
      }

      await _refreshPendingCount();
      if (_pendingCount == 0) {
        _state = SyncUiState.synced;
        _lastSyncedAt = DateTime.now();
      } else {
        _state = SyncUiState.pendingSync;
      }
    } catch (e) {
      debugPrint('SyncEngine.triggerSyncNow error: $e');
      _state = SyncUiState.failedSync;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncItem(SyncQueueItem item) async {
    final db = OfflineDatabase.instance.isar;

    await db.writeTxn(() async {
      item.status = SyncItemStatus.syncing;
      item.updatedAt = DateTime.now();
      await db.syncQueueItems.put(item);
    });

    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final uri = Uri.parse('${AuthService.baseUrl}${item.endpoint}');
      final body = item.payloadJson;
      http.Response response;

      switch (item.method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: body);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: body);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported method: ${item.method}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await db.writeTxn(() async {
          item.status = SyncItemStatus.synced;
          item.syncedAt = DateTime.now();
          item.updatedAt = DateTime.now();
          item.lastError = null;
          await db.syncQueueItems.put(item);
        });

        await _markCacheEntryClean(item);
        return;
      }

      await _handleSyncFailure(
        item,
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      await _handleSyncFailure(item, e.toString());
    }
  }

  Future<void> _markCacheEntryClean(SyncQueueItem item) async {
    final db = OfflineDatabase.instance.isar;
    final cacheKey = _cacheKeyForSyncItem(item);
    if (cacheKey == null) return;

    await db.writeTxn(() async {
      switch (_entityTypeFromCacheKey(cacheKey)) {
        case 'class':
          final e = await db.classLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.classLocals.put(e);
          }
          break;
        case 'subject':
          final e = await db.subjectLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.subjectLocals.put(e);
          }
          break;
        case 'attendance':
          final e = await db.attendanceLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.attendanceLocals.put(e);
          }
          break;
        case 'assessment':
          final e = await db.assessmentLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.assessmentLocals.put(e);
          }
          break;
        case 'result':
          final e = await db.resultLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.resultLocals.put(e);
          }
          break;
        case 'material':
        case 'document':
          final e = await db.learningMaterialLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.learningMaterialLocals.put(e);
          }
          break;
        case 'announcement':
          final e = await db.announcementLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.announcementLocals.put(e);
          }
          break;
        case 'session':
        case 'academic_session':
          final e = await db.academicSessionLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.academicSessionLocals.put(e);
          }
          break;
        case 'profile':
        case 'user':
          final e = await db.userProfileLocals.getByRemoteId(cacheKey);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.userProfileLocals.put(e);
          }
          break;
        default:
          final genericId = cacheKey.startsWith('cache:') ? cacheKey : 'cache:$cacheKey';
          final e = await db.teacherLocals.getByRemoteId(genericId);
          if (e != null) {
            e.isDirty = false;
            e.updatedAt = DateTime.now();
            await db.teacherLocals.put(e);
          }
          break;
      }
    });
  }

  String _entityTypeFromCacheKey(String cacheKey) {
    final idx = cacheKey.indexOf(':');
    if (idx == -1) return 'generic';
    return cacheKey.substring(0, idx).toLowerCase();
  }

  String? _cacheKeyForSyncItem(SyncQueueItem item) {
    if (item.entityId.contains(':')) return item.entityId;

    switch (item.entityType.toLowerCase()) {
      case 'assignment':
        return 'assignments:${item.entityId}';
      case 'material':
        return 'materials:${item.entityId}';
      default:
        return null;
    }
  }

  Future<void> _handleSyncFailure(SyncQueueItem item, String reason) async {
    final db = OfflineDatabase.instance.isar;
    final retries = item.retryCount + 1;
    final backoffSeconds = _computeBackoffSeconds(retries);

    await db.writeTxn(() async {
      item.retryCount = retries;
      item.lastError = reason;
      item.updatedAt = DateTime.now();
      item.nextRetryAt = DateTime.now().add(Duration(seconds: backoffSeconds));
      item.status = retries >= item.maxRetries
          ? SyncItemStatus.failed
          : SyncItemStatus.pending;
      await db.syncQueueItems.put(item);
    });

    _state = SyncUiState.failedSync;
  }

  int _computeBackoffSeconds(int retryCount) {
    const base = 2;
    const maxSeconds = 300;
    final seconds = (1 << retryCount).clamp(base, maxSeconds);
    return seconds;
  }

  /// Clear all synced items older than [olderThan] days.
  Future<void> clearSyncedHistory({int olderThanDays = 7}) async {
    final db = OfflineDatabase.instance.isar;
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));

    await db.writeTxn(() async {
      await db.syncQueueItems
          .filter()
          .statusEqualTo(SyncItemStatus.synced)
          .syncedAtLessThan(cutoff)
          .findAll()
          .then((items) async {
        for (final item in items) {
          await db.syncQueueItems.delete(item.id);
        }
      });
    });
  }

  /// Get detailed list of pending/failed items for the sync screen
  Future<List<SyncQueueItem>> getFailedItems() async {
    final db = OfflineDatabase.instance.isar;
    return db.syncQueueItems
        .filter()
        .statusEqualTo(SyncItemStatus.failed)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> resolveConflictLatestWins({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localPayload,
    required Map<String, dynamic> serverPayload,
  }) async {
    final db = OfflineDatabase.instance.isar;
    final localUpdatedAt = DateTime.tryParse('${localPayload['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final serverUpdatedAt = DateTime.tryParse('${serverPayload['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);

    final resolution = localUpdatedAt.isAfter(serverUpdatedAt) ? 'local_won' : 'server_won';

    await db.writeTxn(() async {
      final log = ConflictLog()
        ..entityType = entityType
        ..entityId = entityId
        ..localPayloadJson = jsonEncode(localPayload)
        ..serverPayloadJson = jsonEncode(serverPayload)
        ..localUpdatedAt = localUpdatedAt
        ..serverUpdatedAt = serverUpdatedAt
        ..resolution = resolution
        ..createdAt = DateTime.now();
      await db.conflictLogs.put(log);
    });
  }

  /// Retry a single failed item
  Future<bool> retryItem(int itemId) async {
    final db = OfflineDatabase.instance.isar;
    final item = await db.syncQueueItems.get(itemId);
    if (item == null) return false;

    await db.writeTxn(() async {
      item.retryCount = 0;
      item.status = SyncItemStatus.pending;
      item.lastError = null;
      item.nextRetryAt = null;
      item.updatedAt = DateTime.now();
      await db.syncQueueItems.put(item);
    });

    await _refreshPendingCount();
    _state = SyncUiState.pendingSync;
    notifyListeners();
    return true;
  }

  /// Remove a queued item permanently
  Future<void> removeItem(int itemId) async {
    final db = OfflineDatabase.instance.isar;
    await db.writeTxn(() async {
      await db.syncQueueItems.delete(itemId);
    });
    await _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final db = OfflineDatabase.instance.isar;
    final pending = await db.syncQueueItems
        .filter()
        .statusEqualTo(SyncItemStatus.pending)
        .count();
    final failed = await db.syncQueueItems
        .filter()
        .statusEqualTo(SyncItemStatus.failed)
        .count();
    _pendingCount = pending + failed;
    notifyListeners();
  }

  static void _backgroundSyncDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        await OfflineDatabase.instance.init();
        await SyncEngine.instance.init();
        await SyncEngine.instance.triggerSyncNow();
      } catch (_) {}
      return Future.value(true);
    });
  }
}
