import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';
import '../services/baserow_service.dart';
import '../theme/premium_theme.dart';

class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  bool _isOnline = false;
  bool _isSyncing = false;
  String _lastSyncStatus = 'Never synced';
  bool _hasPendingChanges = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadSyncStatus();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _loadSyncStatus() async {
    final lastSync = await SyncService.getLastSyncTime();
    final pendingChanges = await SyncService.getPendingChanges();
    
    setState(() {
      if (lastSync != null) {
        final now = DateTime.now();
        final difference = now.difference(lastSync);
        
        if (difference.inMinutes < 1) {
          _lastSyncStatus = 'Just now';
        } else if (difference.inHours < 1) {
          _lastSyncStatus = '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          _lastSyncStatus = '${difference.inHours}h ago';
        } else {
          _lastSyncStatus = '${difference.inDays}d ago';
        }
      }
      _hasPendingChanges = pendingChanges.isNotEmpty;
    });
  }

  Future<void> _performSync() async {
    if (!_isOnline) {
      _showSnackBar('No internet connection', isError: true);
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await SyncService.performFullSync();
      if (result.success) {
        await _loadSyncStatus();
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {}

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small Status Icon
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 12,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Compact Status Info
          Text(
            _getStatusText(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
          
          const SizedBox(width: 4),
          
          Text(
            _lastSyncStatus,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
          ),
          
          // Small Sync Button
          if (_isOnline && !_isSyncing) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _performSync,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync,
                      size: 12,
                      color: PremiumTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 10,
                        color: PremiumTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!_isOnline) return PremiumTheme.errorColor;
    if (_isSyncing) return PremiumTheme.primaryColor;
    if (_hasPendingChanges) return PremiumTheme.warningColor;
    return PremiumTheme.successColor;
  }

  Color _getBorderColor() {
    if (!_isOnline) return PremiumTheme.errorColor.withOpacity(0.3);
    if (_hasPendingChanges) return PremiumTheme.warningColor.withOpacity(0.3);
    return PremiumTheme.successColor.withOpacity(0.3);
  }

  IconData _getStatusIcon() {
    if (!_isOnline) return Icons.wifi_off;
    if (_isSyncing) return Icons.sync;
    if (_hasPendingChanges) return Icons.sync_problem;
    return Icons.check_circle;
  }

  String _getStatusText() {
    if (!_isOnline) return 'Offline';
    if (_isSyncing) return 'Syncing...';
    if (_hasPendingChanges) return 'Sync needed';
    return 'Synced';
  }
}