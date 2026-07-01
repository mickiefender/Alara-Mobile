import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:alara/core/offline/sync/sync_status.dart';

class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityMode _mode = ConnectivityMode.other;
  ConnectivityMode get mode => _mode;

  bool get isOnline =>
      _mode == ConnectivityMode.mobile ||
      _mode == ConnectivityMode.wifi ||
      _mode == ConnectivityMode.other;

  Future<void> init({VoidCallback? onConnectivityRestored}) async {
    final initial = await _connectivity.checkConnectivity();
    _mode = _toMode(initial);
    notifyListeners();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final previous = _mode;
      _mode = _toMode(results);
      notifyListeners();

      if (previous == ConnectivityMode.offline && isOnline) {
        onConnectivityRestored?.call();
      }
    });
  }

  ConnectivityMode _toMode(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      return ConnectivityMode.offline;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return ConnectivityMode.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityMode.mobile;
    }
    return ConnectivityMode.other;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
