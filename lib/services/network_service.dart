import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isConnected = false;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    _connectionController.add(_isConnected);

    // Start auto-sync timer
    _startAutoSyncTimer();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasConnected = _isConnected;
        _isConnected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
        
        if (_isConnected != wasConnected) {
          _connectionController.add(_isConnected);
          
          if (_isConnected && !wasConnected) {
            // Just came online - trigger immediate sync for faster updates
            _triggerImmediateSync();
          }
        }
      },
    );
  }

  Timer? _autoSyncTimer;

  void _startAutoSyncTimer() {
    // Auto-sync every 30 seconds when connected
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        SyncService.checkAndSyncIfNeeded().catchError((e) {
          debugPrint('Auto-sync failed: $e');
        });
      }
    });
  }

  void _triggerAutoSync() {
    // Auto-sync when connection is restored
    SyncService.autoSync().catchError((e) {
      debugPrint('Auto-sync failed: $e');
    });
  }

  /// Trigger immediate sync when connection is restored
  void _triggerImmediateSync() {
    // Force immediate sync when coming back online
    SyncService.forceSync().catchError((e) {
      debugPrint('Immediate sync failed: $e');
    });
  }

  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
