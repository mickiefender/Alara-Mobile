import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:alara/core/offline/sync/connectivity_monitor.dart';
import 'package:alara/core/offline/sync/sync_engine.dart';
import 'package:alara/core/offline/sync/sync_status.dart';

class SyncStateProvider extends ChangeNotifier {
  final ConnectivityMonitor connectivityMonitor;
  final SyncEngine syncEngine;

  SyncStateProvider({
    required this.connectivityMonitor,
    required this.syncEngine,
  }) {
    connectivityMonitor.addListener(_relay);
    syncEngine.addListener(_relay);
  }

  SyncUiState get syncState => syncEngine.state;
  ConnectivityMode get connectivity => connectivityMonitor.mode;
  int get pendingChanges => syncEngine.pendingCount;
  DateTime? get lastSyncedAt => syncEngine.lastSyncedAt;

  String get lastSyncedLabel {
    final value = lastSyncedAt;
    if (value == null) return 'Never';
    return DateFormat('y-MM-dd HH:mm').format(value);
  }

  bool get showOfflineBanner => connectivity == ConnectivityMode.offline;

  Future<void> syncNow() => syncEngine.triggerSyncNow();

  void _relay() => notifyListeners();

  @override
  void dispose() {
    connectivityMonitor.removeListener(_relay);
    syncEngine.removeListener(_relay);
    super.dispose();
  }
}
