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
      version: 5,
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
  plan_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
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
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

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
  updated_at TEXT NOT NULL
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
  FOREIGN KEY (project_id) REFERENCES projects (id)
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
  FOREIGN KEY (project_id) REFERENCES projects (id),
  FOREIGN KEY (task_id) REFERENCES tasks (id)
)
''');

    // Plans table
    await db.execute('''
CREATE TABLE plans (
  id $idType,
  project_id $intType,
  job_number $textType,
  name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects (id)
)
''');

    // Plan Images table
    await db.execute('''
CREATE TABLE plan_images (
  id $idType,
  plan_id $intType,
  image_path $textType,
  name $textType,
  created_at TEXT NOT NULL,
  FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
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
  status TEXT DEFAULT 'Priority 2',
  created_at TEXT NOT NULL,
  FOREIGN KEY (plan_image_id) REFERENCES plan_images (id) ON DELETE CASCADE
)
''');

    // Pin Comments table
    await db.execute('''
CREATE TABLE pin_comments (
  id $idType,
  pin_id $intType,
  type $textType,
  text TEXT,
  image_path TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pin_id) REFERENCES pins (id) ON DELETE CASCADE
)
''');
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}

