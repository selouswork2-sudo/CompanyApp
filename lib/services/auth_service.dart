import 'package:shared_preferences/shared_preferences.dart';
import 'baserow_service.dart';
import '../models/user.dart';

class AuthService {
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _usernameKey = 'username';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _nameKey = 'name';

  static User? _currentUser;
  
  static User? get currentUser => _currentUser;
  
  static bool get isLoggedIn => _currentUser != null;

  // Check if user is logged in (async version for initial check)
  static Future<bool> isLoggedInAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      print('❌ AuthService.isLoggedIn error: $e');
      print('⚠️ SharedPreferences corrupted, returning false');
      return false;
    }
  }

  // Login user with Baserow integration
  static Future<bool> login(String username, String password) async {
    try {
      // Get user from Baserow
      final user = await BaserowService.getUser(username);
      
      if (user != null) {
        // Check password - skip password check for now (we'll add hash later)
        // For now, just check if user exists
        
        // Check if user is already active (skip for now - session management will be added later)
        // final isActive = user['field_7497'] as String?;
        // if (isActive == 'true') {
        //   return false; // User already logged in elsewhere
        // }
        
        // Create user object
        final roleObject = user['field_7492'] as Map<String, dynamic>?;
        final roleValue = roleObject?['value'] as String?;
        UserRole role;
        switch (roleValue) {
          case 'Manager':
            role = UserRole.manager;
            break;
          case 'Supervisor':
            role = UserRole.supervisor;
            break;
          case 'Technician':
            role = UserRole.technician;
            break;
          default:
            role = UserRole.technician;
        }
        
        _currentUser = User(
          id: user['field_7490'] as String, // username
          name: user['field_7490'] as String, // username (no name field yet)
          email: user['field_7491'] as String, // email
          role: role,
        );
          
          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_usernameKey, username);
          await prefs.setString(_userIdKey, _currentUser!.id);
          await prefs.setString(_userRoleKey, role.name);
          await prefs.setString(_nameKey, _currentUser!.name);
          
          // Otomatik olarak is_active = true yap
          await BaserowService.updateUserSession(username, {
            'is_active': true,
            'last_activity': DateTime.now().toIso8601String(),
          });
          
          return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  // Logout user
  static Future<void> logout() async {
    // Otomatik olarak is_active = false yap
    if (_currentUser != null) {
      BaserowService.updateUserSession(_currentUser!.id, {
        'is_active': false,
        'last_activity': DateTime.now().toIso8601String(),
      }).catchError((e) {
        print('❌ Logout update failed: $e');
      });
    }
    
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_nameKey);
  }

  // Get current user info
  static Future<Map<String, String?>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_usernameKey),
      'userId': prefs.getString(_userIdKey),
      'userRole': prefs.getString(_userRoleKey),
      'name': prefs.getString(_nameKey),
    };
  }

  // Get name
  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  // Get username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }
}