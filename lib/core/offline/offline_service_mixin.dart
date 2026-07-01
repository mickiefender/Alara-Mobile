import 'package:flutter/foundation.dart';
import 'package:alara/core/offline/offline_cache.dart';
import 'package:alara/core/offline/sync/sync_engine.dart';
import 'package:alara/core/offline/models/local_entities.dart';

/// Mixin that provides offline-first caching and write queuing to any service.
///
/// The pattern:
///   - **Reads**: try the online API. On success, cache the response and return it.
///     On failure (network or server), fall back to the Isar cache.
///   - **Writes**: try the online API. On failure, queue via [SyncEngine] for later
///     and store the payload in the local cache with isDirty=true.
mixin OfflineAwareService {
  final OfflineCache _offlineCache = OfflineCache.instance;
  final SyncEngine _syncEngine = SyncEngine.instance;

  // ------------------------------------------------------------------
  // OFFLINE-FIRST READ HELPERS
  // ------------------------------------------------------------------

  /// Fetch from the API, cache on success, fall back to cache on failure.
  ///
  /// [cacheKey] is the key used to store/retrieve the cached JSON.
  /// [fetchFn] is the async HTTP call returning decoded JSON or null.
  /// Returns the API result on success, cached result on failure, or null.
  Future<Map<String, dynamic>?> offlineFirstRead({
    required String cacheKey,
    required Future<Map<String, dynamic>?> Function() fetchFn,
  }) async {
    try {
      final result = await fetchFn();
      if (result != null) {
        await _offlineCache.set(cacheKey, result);
        return result;
      }

      // Null result from fetch is treated as a failure-like outcome.
      final cached = await _offlineCache.get(cacheKey);
      if (cached != null) {
        debugPrint('offlineFirstRead: fetch returned null, using cached data for $cacheKey');
      }
      return cached;
    } catch (e) {
      debugPrint('offlineFirstRead: fetch failed for $cacheKey: $e');
      // Fall back to cache
      final cached = await _offlineCache.get(cacheKey);
      if (cached != null) {
        debugPrint('offlineFirstRead: returning cached data for $cacheKey');
      }
      return cached;
    }
  }

  /// Same as [offlineFirstRead] but for list responses.
  Future<List<Map<String, dynamic>>?> offlineFirstReadList({
    required String cacheKey,
    required Future<List<Map<String, dynamic>>?> Function() fetchFn,
  }) async {
    try {
      final result = await fetchFn();
      if (result != null) {
        await _offlineCache.set(cacheKey, result);
        return result;
      }

      final cached = await _offlineCache.getList(cacheKey);
      if (cached != null) {
        debugPrint('offlineFirstReadList: fetch returned null, using cached data for $cacheKey');
      }
      return cached;
    } catch (e) {
      debugPrint('offlineFirstReadList: fetch failed for $cacheKey: $e');
      final cached = await _offlineCache.getList(cacheKey);
      if (cached != null) {
        debugPrint('offlineFirstReadList: returning cached data for $cacheKey');
      }
      return cached;
    }
  }

  /// Try a write operation; if it fails, queue it for later sync.
  ///
  /// [entityType] and [entityId] identify the domain object.
  /// [endpoint] is the API path (e.g. "/api/attendance/bulk_mark/").
  /// [method] is HTTP method (POST, PATCH, PUT, DELETE).
  /// [payload] is the request body.
  /// [cacheKey] is used to update the local cache so the UI is immediately consistent.
  /// [writeFn] is the actual HTTP call. If it succeeds, the result is returned.
  /// If it fails (network or server error), the operation is queued.
  ///
  /// Returns true if the write was performed online, false if queued.
  Future<bool> offlineFirstWrite({
    required String entityType,
    required String entityId,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String? cacheKey,
    required Future<bool> Function() writeFn,
  }) async {
    try {
      final success = await writeFn();
      if (success) {
        // Update cache with the latest payload
        if (cacheKey != null) {
          await _offlineCache.set(cacheKey, payload);
        }
        return true;
      }
      // Server returned error — queue for retry
      await _enqueueWrite(
        entityType: entityType,
        entityId: entityId,
        operationType: _operationTypeForMethod(method),
        endpoint: endpoint,
        method: method,
        payload: payload,
        cacheKey: cacheKey,
      );
      return false;
    } catch (e) {
      debugPrint('offlineFirstWrite: write failed for $endpoint: $e');
      // Network error — queue for retry
      await _enqueueWrite(
        entityType: entityType,
        entityId: entityId,
        operationType: _operationTypeForMethod(method),
        endpoint: endpoint,
        method: method,
        payload: payload,
        cacheKey: cacheKey,
      );
      return false;
    }
  }

  // ------------------------------------------------------------------
  // CACHE ONLY HELPERS
  // ------------------------------------------------------------------

  /// Read directly from cache (no online attempt).
  Future<Map<String, dynamic>?> readFromCache(String cacheKey) =>
      _offlineCache.get(cacheKey);

  /// Read a list from cache (no online attempt).
  Future<List<Map<String, dynamic>>?> readListFromCache(String cacheKey) =>
      _offlineCache.getList(cacheKey);

  /// Write to cache only (for local-only data).
  Future<void> writeToCache(String cacheKey, dynamic data) =>
      _offlineCache.set(cacheKey, data);

  /// Check if cached data exists and is fresh.
  Future<bool> hasCache(String cacheKey, {Duration maxAge = const Duration(hours: 1)}) =>
      _offlineCache.has(cacheKey, maxAge: maxAge);

  // ------------------------------------------------------------------
  // INTERNALS
  // ------------------------------------------------------------------

  Future<void> _enqueueWrite({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String? cacheKey,
  }) async {
    // Update cache optimistically
    if (cacheKey != null) {
      await _offlineCache.set(cacheKey, payload);
      await _offlineCache.markDirty(cacheKey);
    }

    await _syncEngine.enqueue(
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      endpoint: endpoint,
      method: method,
      payload: payload,
    );
  }

  SyncOperationType _operationTypeForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return SyncOperationType.create;
      case 'PATCH':
      case 'PUT':
        return SyncOperationType.update;
      case 'DELETE':
        return SyncOperationType.delete;
      default:
        return SyncOperationType.create;
    }
  }
}
