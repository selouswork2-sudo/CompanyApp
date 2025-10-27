import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'baserow_service.dart';

class SessionManager {
  static const String _deviceIdKey = 'device_id';
  static const String _userIdKey = 'user_id';
  static const String _sessionTokenKey = 'session_token';
  
  static String? _currentDeviceId;
  static String? _currentUserId;
  static String? _currentSessionToken;

  /// Initialize device ID
  static Future<String> _getDeviceId() async {
    if (_currentDeviceId != null) return _currentDeviceId!;
    
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      // Generate unique device ID
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = 'ios_${iosInfo.identifierForVendor}_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isWindows) {
        deviceId = 'windows_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    _currentDeviceId = deviceId;
    return deviceId;
  }

  /// Get device name for display
  static Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.brand} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} (${iosInfo.model})';
    } else if (Platform.isWindows) {
      return 'Windows PC';
    } else {
      return 'Unknown Device';
    }
  }

  /// Check if user can login (not already logged in elsewhere)
  static Future<LoginResult> canLogin(String userId) async {
    try {
      // Check user's current session
      final user = await BaserowService.getUser(userId);
      
      if (user != null && user['field_7343'] == 'true') {
        return LoginResult(
          canLogin: false,
          message: 'Bu kullanıcı başka bir cihazda aktif',
          activeDevices: [{'device_name': 'Başka Cihaz'}],
        );
      }
      
      return LoginResult(canLogin: true, message: 'Giriş yapabilirsiniz');
      
    } catch (e) {
      print('❌ Error checking login status: $e');
      return LoginResult(
        canLogin: true, // Allow login on error
        message: 'Bağlantı hatası, giriş yapılıyor...',
      );
    }
  }

  /// Login user and create session
  static Future<bool> login(String userId, String userName) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final sessionToken = '${userId}_${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Update user's session info in Baserow
      await BaserowService.updateUserSession(userId, {
        'is_active': true,
        'last_activity': DateTime.now().toIso8601String(),
      });
      
      // Store locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_sessionTokenKey, sessionToken);
      
      _currentUserId = userId;
      _currentSessionToken = sessionToken;
      
      print('✅ User logged in: $userName on $deviceName');
      return true;
      
    } catch (e) {
      print('❌ Login failed: $e');
      return false;
    }
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      if (_currentUserId != null) {
        // Deactivate user session in Baserow
        await BaserowService.updateUserSession(_currentUserId!, {
          'is_active': false,
          'last_activity': DateTime.now().toIso8601String(),
        });
      }
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_sessionTokenKey);
      
      _currentUserId = null;
      _currentSessionToken = null;
      
      print('✅ User logged out');
      
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    if (_currentUserId != null) return true;
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final sessionToken = prefs.getString(_sessionTokenKey);
    
    if (userId != null && sessionToken != null) {
      // Verify session is still active
      final user = await BaserowService.getUser(userId);
      
      if (user != null && user['field_7343'] == 'true') {
        _currentUserId = userId;
        _currentSessionToken = sessionToken;
        return true;
      } else {
        // Session expired, clear local data
        await prefs.remove(_userIdKey);
        await prefs.remove(_sessionTokenKey);
      }
    }
    
    return false;
  }

  /// Update last activity
  static Future<void> updateActivity() async {
    if (_currentUserId != null) {
      try {
        await BaserowService.updateUserSession(_currentUserId!, {
          'last_activity': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('❌ Failed to update activity: $e');
      }
    }
  }

  /// Force logout from other devices
  static Future<bool> forceLogoutOthers(String userId) async {
    try {
      // Simply deactivate user - this will logout from all devices
      await BaserowService.updateUserSession(userId, {
        'is_active': false,
        'last_activity': DateTime.now().toIso8601String(),
      });
      print('✅ Logged out from other devices');
      return true;
    } catch (e) {
      print('❌ Failed to logout others: $e');
      return false;
    }
  }
}

class LoginResult {
  final bool canLogin;
  final String message;
  final List<Map<String, dynamic>>? activeDevices;
  
  LoginResult({
    required this.canLogin,
    required this.message,
    this.activeDevices,
  });
}
