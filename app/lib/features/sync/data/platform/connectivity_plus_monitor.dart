import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/repositories/connectivity_monitor.dart';

/// [ConnectivityMonitor] from the OS (connectivity_plus). Any connection
/// type counts; whether the server is reachable is found out by syncing.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  const ConnectivityPlusMonitor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> watchOnline() async* {
    var last = _online(await _connectivity.checkConnectivity());
    yield last;
    await for (final results in _connectivity.onConnectivityChanged) {
      final online = _online(results);
      if (online != last) yield last = online;
    }
  }

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
