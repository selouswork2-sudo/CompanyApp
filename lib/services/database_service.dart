import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('company_field_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 23, // Added updated_at to pins table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add plan_images table
      await db.execute('''
CREATE TABLE plan_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (job_id) REFERENCES plans (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 10) {
      // Add sync metadata columns to projects table
      await db.execute('ALTER TABLE projects ADD COLUMN baserow_id INTEGER');
      await db.execute('ALTER TABLE projects ADD COLUMN sync_status TEXT DEFAULT "synced"');
      await db.execute('ALTER TABLE projects ADD COLUMN last_sync TEXT');
      await db.execute('ALTER TABLE projects ADD COLUMN needs_sync INTEGER DEFAULT 0');
    }
    if (oldVersion < 16) {
      // Fix plan_images table schema - change plan_id to job_id
      await db.execute('DROP TABLE IF EXISTS plan_images');
      await db.execute('''
CREATE TABLE plan_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'synced',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 0,
  FOREIGN KEY (job_id) REFERENCES plans (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 17) {
      // Enable foreign key constraints and add cascade delete
      await db.execute('PRAGMA foreign_keys = ON');
      
      // Recreate tables with proper cascade delete
      await db.execute('DROP TABLE IF EXISTS timesheets');
      await db.execute('''
CREATE TABLE timesheets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  plan_id INTEGER,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
)
''');
      
      await db.execute('DROP TABLE IF EXISTS tasks');
      await db.execute('''
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'Open',
  priority TEXT DEFAULT 'Medium',
  assignee TEXT,
  due_date TEXT,
  location TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
)
''');
      
      await db.execute('DROP TABLE IF EXISTS photos');
      await db.execute('''
CREATE TABLE photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  task_id INTEGER,
  uri TEXT NOT NULL,
  title TEXT,
  description TEXT,
  latitude REAL,
  longitude REAL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
)
''');
      
      // Recreate plans table with cascade delete
      await db.execute('DROP TABLE IF EXISTS plans');
      await db.execute('''
CREATE TABLE plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  job_number TEXT NOT NULL UNIQUE,
  name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'synced',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
)
''');
    }

    if (oldVersion < 18) {
      // Add job status and user management
      await db.execute('PRAGMA foreign_keys = ON');
      
      // Add status column to plans table (jobs)
      await db.execute('ALTER TABLE plans ADD COLUMN status TEXT DEFAULT "pending"');
      await db.execute('ALTER TABLE plans ADD COLUMN description TEXT');
      await db.execute('ALTER TABLE plans ADD COLUMN assigned_to TEXT');
      await db.execute('ALTER TABLE plans ADD COLUMN due_date TEXT');
      
      // Create users table
      await db.execute('''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
      
      // Create pending_changes table for simple sync
      await db.execute('''
CREATE TABLE pending_changes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action TEXT NOT NULL,
  data TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 3) {
      // Add pins table
      await db.execute('''
CREATE TABLE pins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_image_id INTEGER NOT NULL,
  x REAL NOT NULL,
  y REAL NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  assigned_to TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (plan_image_id) REFERENCES plan_images (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 4) {
      // Add status column to pins
      await db.execute('ALTER TABLE pins ADD COLUMN status TEXT DEFAULT "Priority 2"');
    }
    if (oldVersion < 5) {
      // Add pin_comments table
      await db.execute('''
CREATE TABLE pin_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pin_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  text TEXT,
  image_path TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pin_id) REFERENCES pins (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 6) {
      // Add timesheets table
      await db.execute('''
CREATE TABLE timesheets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  plan_id INTEGER,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id),
  FOREIGN KEY (plan_id) REFERENCES plans (id)
)
''');
    }
    if (oldVersion < 7) {
      // Add pin_photos table
      await db.execute('''
CREATE TABLE pin_photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pin_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pin_id) REFERENCES pins (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 8) {
      // Add category column to pin_photos table
      await db.execute('ALTER TABLE pin_photos ADD COLUMN category TEXT DEFAULT "before"');
    }
    if (oldVersion < 9) {
      // Add timesheets table if it doesn't exist
      await db.execute('''
CREATE TABLE IF NOT EXISTS timesheets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  plan_id INTEGER,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id),
  FOREIGN KEY (plan_id) REFERENCES plans (id)
)
''');
    }
    if (oldVersion < 19) {
      // Add sync metadata columns to pins table
      await db.execute('ALTER TABLE pins ADD COLUMN baserow_id INTEGER');
      await db.execute('ALTER TABLE pins ADD COLUMN sync_status TEXT DEFAULT "pending"');
      await db.execute('ALTER TABLE pins ADD COLUMN last_sync TEXT');
      await db.execute('ALTER TABLE pins ADD COLUMN needs_sync INTEGER DEFAULT 1');
    }
    if (oldVersion < 20) {
      // Add photo URL fields to pins table
      await db.execute('ALTER TABLE pins ADD COLUMN before_pictures_urls TEXT');
      await db.execute('ALTER TABLE pins ADD COLUMN during_pictures_urls TEXT');
      await db.execute('ALTER TABLE pins ADD COLUMN after_pictures_urls TEXT');
    }
    if (oldVersion < 21) {
      // Add local photo path fields to pins table
      await db.execute('ALTER TABLE pins ADD COLUMN before_pictures_local TEXT');
      await db.execute('ALTER TABLE pins ADD COLUMN during_pictures_local TEXT');
      await db.execute('ALTER TABLE pins ADD COLUMN after_pictures_local TEXT');
      // Add local image path to plan_images table
      await db.execute('ALTER TABLE plan_images ADD COLUMN local_image_path TEXT');
    }
    
    if (oldVersion < 22) {
      // Add sync_settings table for tracking sync timestamps
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT UNIQUE NOT NULL,
          value TEXT NOT NULL
        )
      ''');
    }
    
    if (oldVersion < 23) {
      // Add updated_at column to pins table
      await db.execute('ALTER TABLE pins ADD COLUMN updated_at TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');

    // Projects table
    await db.execute('''
CREATE TABLE projects (
  id $idType,
  name $textType,
  address TEXT,
  status TEXT DEFAULT 'Active',
  start_date TEXT,
  end_date TEXT,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'synced',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 0
)
''');

    // Tasks table
    await db.execute('''
CREATE TABLE tasks (
  id $idType,
  project_id $intType,
  title $textType,
  description TEXT,
  status TEXT DEFAULT 'Open',
  priority TEXT DEFAULT 'Medium',
  assignee TEXT,
  due_date TEXT,
  location TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
)
''');

    // Photos table
    await db.execute('''
CREATE TABLE photos (
  id $idType,
  project_id $intType,
  task_id INTEGER,
  uri $textType,
  title TEXT,
  description TEXT,
  latitude REAL,
  longitude REAL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
)
''');

    // Plans table
    await db.execute('''
CREATE TABLE IF NOT EXISTS plans (
  id $idType,
  project_id $intType,
  job_number $textType UNIQUE,
  name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'synced',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
)
''');

    // Timesheets table
    await db.execute('''
CREATE TABLE timesheets (
  id $idType,
  project_id $intType,
  plan_id INTEGER,
  user_id $textType,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
)
''');

    // Plan Images table
    await db.execute('''
CREATE TABLE plan_images (
  id $idType,
  job_id $intType,
  image_path $textType,
  name $textType,
  local_image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'synced',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 0,
  FOREIGN KEY (job_id) REFERENCES plans (id) ON DELETE CASCADE
)
''');

    // Forms table
    await db.execute('''
CREATE TABLE forms (
  id $idType,
  project_id $intType,
  name $textType,
  type TEXT,
  status TEXT DEFAULT 'Pending',
  data TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id)
)
''');

    // Punch List table
    await db.execute('''
CREATE TABLE punch_list (
  id $idType,
  project_id $intType,
  title $textType,
  description TEXT,
  status TEXT DEFAULT 'Open',
  priority TEXT DEFAULT 'Medium',
  location TEXT,
  assigned_to TEXT,
  due_date TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id)
)
''');

    // Files table
    await db.execute('''
CREATE TABLE files (
  id $idType,
  project_id $intType,
  name $textType,
  uri $textType,
  type TEXT,
  size INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id)
)
''');

    // Team members table
    await db.execute('''
CREATE TABLE team_members (
  id $idType,
  name $textType,
  email TEXT,
  role TEXT,
  phone TEXT,
  created_at TEXT NOT NULL
)
''');

    // Pins table
    await db.execute('''
CREATE TABLE pins (
  id $idType,
  plan_image_id $intType,
  x REAL NOT NULL,
  y REAL NOT NULL,
  title $textType,
  description TEXT,
  assigned_to TEXT,
  status TEXT DEFAULT 'Open',
  created_at TEXT NOT NULL,
  updated_at TEXT,
  before_pictures_urls TEXT,
  during_pictures_urls TEXT,
  after_pictures_urls TEXT,
  before_pictures_local TEXT,
  during_pictures_local TEXT,
  after_pictures_local TEXT,
  baserow_id INTEGER,
  sync_status TEXT DEFAULT 'pending',
  last_sync TEXT,
  needs_sync INTEGER DEFAULT 1,
  FOREIGN KEY (plan_image_id) REFERENCES plan_images (id) ON DELETE CASCADE
)
''');

    // Pin Photos table
    await db.execute('''
CREATE TABLE pin_photos (
  id $idType,
  pin_id $intType,
  image_path $textType,
  category TEXT DEFAULT 'before',
  created_at TEXT NOT NULL,
  FOREIGN KEY (pin_id) REFERENCES pins (id) ON DELETE CASCADE
)
''');

    // Pin Comments table
    await db.execute('''
CREATE TABLE pin_comments (
  id $idType,
  pin_id $intType,
  user_id $textType,
  comment $textType,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pin_id) REFERENCES pins (id) ON DELETE CASCADE
)
''');

    // Pending Changes table
    await db.execute('''
CREATE TABLE pending_changes (
  id $idType,
  action $textType,
  data $textType,
  created_at TEXT NOT NULL
)
''');

    // Sync Settings table
    await db.execute('''
CREATE TABLE sync_settings (
  id $idType,
  key TEXT UNIQUE NOT NULL,
  value $textType
)
''');

  }

  // Generic CRUD operations with error handling
  Future<int> insert(String table, Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert(table, data);
    } catch (e) {
      throw Exception('Failed to insert into $table: $e');
    }
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      return await db.query(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw Exception('Failed to query $table: $e');
    }
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    try {
      final db = await database;
      return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to update $table: $e');
    }
  }

  Future<int> delete(String table, int id) async {
    try {
      final db = await database;
      return await db.delete(table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete from $table: $e');
    }
  }

  // Batch operations for better performance
  Future<void> batchInsert(String table, List<Map<String, dynamic>> dataList) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final data in dataList) {
        batch.insert(table, data);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch insert into $table: $e');
    }
  }

  // Clear all data (for debugging/reset)
  Future<void> clearAllData() async {
    try {
      final db = await database;
      final batch = db.batch();
      
      // Delete in correct order to respect foreign keys
      batch.delete('pin_comments');
      batch.delete('pins');
      batch.delete('plan_images');
      batch.delete('timesheets');
      batch.delete('plans');
      batch.delete('projects');
      batch.delete('tasks');
      batch.delete('photos');
      batch.delete('forms');
      batch.delete('punch_list');
      batch.delete('files');
      batch.delete('team_members');
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}

