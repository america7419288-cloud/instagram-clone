import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionManager {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    // connectivity_plus 6.x returns a List<ConnectivityResult>
    final bool hasConnection = results.any((result) => result != ConnectivityResult.none);
    
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _connectionController.add(_isOnline);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}
