import 'package:shared_preferences/shared_preferences.dart';

class LocalUser {
  final String username;
  final String password;
  final String role;
  final String name;

  LocalUser({
    required this.username,
    required this.password,
    required this.role,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'name': name,
    };
  }

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
    );
  }
}

class LocalUserService {
  static const String _usersKey = 'local_users';
  
  // Predefined users
  static final List<LocalUser> _predefinedUsers = [
    LocalUser(username: 'manager1', password: 'password', role: 'manager', name: 'Manager One'),
    LocalUser(username: 'manager2', password: 'password', role: 'manager', name: 'Manager Two'),
    LocalUser(username: 'supervisor1', password: 'password', role: 'supervisor', name: 'Supervisor One'),
    LocalUser(username: 'supervisor2', password: 'password', role: 'supervisor', name: 'Supervisor Two'),
    LocalUser(username: 'technician1', password: 'password', role: 'technician', name: 'Technician One'),
    LocalUser(username: 'technician2', password: 'password', role: 'technician', name: 'Technician Two'),
  ];

  // Initialize local users
  static Future<void> initializeUsers() async {
    try {
      // Always return predefined users for now
      // No need to store in SharedPreferences
      print('✅ LocalUserService initialized successfully');
    } catch (e) {
      print('❌ LocalUserService initialization error: $e');
      // Continue anyway, we have predefined users
    }
  }

  // Get all users
  static Future<List<LocalUser>> getAllUsers() async {
    // Return predefined users directly
    return _predefinedUsers;
  }

  // Authenticate user
  static Future<LocalUser?> authenticateUser(String username, String password) async {
    await initializeUsers();
    final users = await getAllUsers();
    
    try {
      final user = users.firstWhere(
        (user) => user.username == username && user.password == password,
      );
      return user;
    } catch (e) {
      return null;
    }
  }

  // Get user by username
  static Future<LocalUser?> getUserByUsername(String username) async {
    await initializeUsers();
    final users = await getAllUsers();
    
    try {
      return users.firstWhere((user) => user.username == username);
    } catch (e) {
      return null;
    }
  }

  // Check if user has permission
  static bool hasPermission(String role, String permission) {
    switch (role) {
      case 'manager':
        return true; // Manager can do everything
      case 'supervisor':
        return _supervisorPermissions.contains(permission);
      case 'technician':
        return _technicianPermissions.contains(permission);
      default:
        return false;
    }
  }

  // Supervisor permissions
  static const List<String> _supervisorPermissions = [
    'view_projects',
    'create_projects',
    'edit_projects',
    'view_timesheets',
    'create_timesheets',
    'edit_timesheets',
    'view_photos',
    'create_photos',
    'view_pins',
    'create_pins',
    'edit_pins',
    'view_plans',
    'create_plans',
    'edit_plans',
    'view_team',
  ];

  // Technician permissions
  static const List<String> _technicianPermissions = [
    'view_projects',
    'view_timesheets',
    'create_timesheets',
    'edit_timesheets',
    'view_photos',
    'create_photos',
    'view_pins',
    'create_pins',
    'view_plans',
  ];

  // Permission constants
  static const String PERMISSION_VIEW_PROJECTS = 'view_projects';
  static const String PERMISSION_CREATE_PROJECTS = 'create_projects';
  static const String PERMISSION_EDIT_PROJECTS = 'edit_projects';
  static const String PERMISSION_DELETE_PROJECTS = 'delete_projects';
  static const String PERMISSION_VIEW_TIMESHEETS = 'view_timesheets';
  static const String PERMISSION_CREATE_TIMESHEETS = 'create_timesheets';
  static const String PERMISSION_EDIT_TIMESHEETS = 'edit_timesheets';
  static const String PERMISSION_DELETE_TIMESHEETS = 'delete_timesheets';
  static const String PERMISSION_VIEW_PHOTOS = 'view_photos';
  static const String PERMISSION_CREATE_PHOTOS = 'create_photos';
  static const String PERMISSION_VIEW_PINS = 'view_pins';
  static const String PERMISSION_CREATE_PINS = 'create_pins';
  static const String PERMISSION_EDIT_PINS = 'edit_pins';
  static const String PERMISSION_DELETE_PINS = 'delete_pins';
  static const String PERMISSION_VIEW_PLANS = 'view_plans';
  static const String PERMISSION_CREATE_PLANS = 'create_plans';
  static const String PERMISSION_EDIT_PLANS = 'edit_plans';
  static const String PERMISSION_DELETE_PLANS = 'delete_plans';
  static const String PERMISSION_VIEW_TEAM = 'view_team';
  static const String PERMISSION_MANAGE_USERS = 'manage_users';
}
