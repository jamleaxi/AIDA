import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has a network path (wifi, mobile
/// data, ethernet, etc.) available. This does not guarantee an active
/// server is reachable, only that the device isn't fully offline.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return _isConnected(results);
  }

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isConnected);

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
