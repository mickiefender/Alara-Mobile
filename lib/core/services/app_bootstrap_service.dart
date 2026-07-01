import 'dart:async';

import 'package:alara/core/offline/offline_database.dart';
import 'package:alara/core/offline/sync/connectivity_monitor.dart';
import 'package:alara/core/offline/sync/sync_engine.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/core/services/notification_service.dart';
import 'package:alara/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.connectivityMonitor,
  });

  final ConnectivityMonitor connectivityMonitor;
}

class AppBootstrapService {
  const AppBootstrapService();

  Future<AppBootstrapResult> bootstrap({
    required AuthProvider authProvider,
  }) async {
    final connectivityMonitor = ConnectivityMonitor();

    await _initializeFirebase();
    await _initializeOfflineDatabase();

    await _initializeConnectivity(connectivityMonitor);

    // Fire-and-forget non-critical startup services.
    unawaited(_initializeSyncEngine());
    unawaited(_initializeNotifications());

    // Required before app routing decisions.
    await authProvider.checkAuthStatus();

    return AppBootstrapResult(connectivityMonitor: connectivityMonitor);
  }

  Future<void> _initializeFirebase() async {
    try {
      debugPrint('Bootstrap: Initializing Firebase');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('Bootstrap warning: Firebase init failed/timed out: $e');
      debugPrint('$st');
    }
  }

  Future<void> _initializeOfflineDatabase() async {
    try {
      debugPrint('Bootstrap: Initializing offline database');
      await OfflineDatabase.instance
          .init()
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('Bootstrap warning: Offline database init failed/timed out: $e');
      debugPrint('$st');
    }
  }

  Future<void> _initializeConnectivity(ConnectivityMonitor connectivityMonitor) async {
    try {
      debugPrint('Bootstrap: Initializing connectivity monitor');
      await connectivityMonitor.init(
        onConnectivityRestored: () {
          SyncEngine.instance.triggerSyncNow();
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e, st) {
      debugPrint('Bootstrap warning: Connectivity monitor init failed/timed out: $e');
      debugPrint('$st');
    }
  }

  Future<void> _initializeSyncEngine() async {
    try {
      debugPrint('Bootstrap: Initializing sync engine (background)');
      await SyncEngine.instance.init().timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('Bootstrap warning: Sync engine init failed/timed out: $e');
      debugPrint('$st');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      debugPrint('Bootstrap: Initializing notifications (background)');
      await NotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 20));
    } catch (e, st) {
      debugPrint('Bootstrap warning: Notifications init failed/timed out: $e');
      debugPrint('$st');
    }
  }
}
