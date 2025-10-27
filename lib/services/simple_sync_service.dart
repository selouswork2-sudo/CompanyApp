import 'dart:convert';
import 'database_service.dart';
import 'baserow_service.dart';

class SimpleSyncService {
  static bool _isSyncing = false;

  /// Simple bidirectional sync
  static Future<bool> sync() async {
    if (_isSyncing) {
      print('⚠️ Sync already in progress');
      return false;
    }
    
    _isSyncing = true;
    
    try {
      print('🔄 Starting simple sync...');
      
      // 1. Upload local changes
      await _uploadLocalChanges();
      
      // 2. Download remote changes
      await _downloadRemoteChanges();
      
      print('✅ Sync completed');
      return true;
      
    } catch (e) {
      print('❌ Sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload local changes to Baserow
  static Future<void> _uploadLocalChanges() async {
    // Get pending changes
    final pendingChanges = await DatabaseService.instance.query('pending_changes');
    
    for (final change in pendingChanges) {
      try {
        final action = change['action'] as String;
        final data = json.decode(change['data'] as String);
        
        switch (action) {
          case 'create_project':
            await BaserowService.createProject(data);
            break;
          case 'update_project':
            await BaserowService.updateProject(data['baserow_id'], data);
            break;
          case 'delete_project':
            await BaserowService.deleteProject(data['baserow_id']);
            break;
          case 'create_job':
            await BaserowService.createJob(data);
            break;
          case 'create_plan':
            await BaserowService.createPlan(data);
            break;
        }
        
        // Remove from pending
        await DatabaseService.instance.delete('pending_changes', change['id']);
        print('✅ Uploaded: $action');
        
      } catch (e) {
        print('❌ Failed to upload ${change['action']}: $e');
      }
    }
  }

  /// Download remote changes from Baserow
  static Future<void> _downloadRemoteChanges() async {
    try {
      // Download projects
      final projects = await BaserowService.getProjects();
      for (final project in projects) {
        await _upsertProject(project);
      }
      
      // Download jobs
      final jobs = await BaserowService.getJobs();
      for (final job in jobs) {
        await _upsertJob(job);
      }
      
      // Download plans
      final plans = await BaserowService.getPlans();
      for (final plan in plans) {
        await _upsertPlan(plan);
      }
      
    } catch (e) {
      print('❌ Failed to download remote changes: $e');
    }
  }

  /// Upsert project (insert or update)
  static Future<void> _upsertProject(Map<String, dynamic> project) async {
    final baserowId = project['id'] as int;
    
    // Check if exists
    final existing = await DatabaseService.instance.query(
      'projects', 
      where: 'baserow_id = ?', 
      whereArgs: [baserowId]
    );
    
    if (existing.isNotEmpty) {
      // Update existing
      await DatabaseService.instance.update('projects', {
        'name': project['field_7234'],
        'address': project['field_7235'],
        'status': project['field_7236'],
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'last_sync': DateTime.now().toIso8601String(),
      }, existing.first['id']);
    } else {
      // Insert new
      await DatabaseService.instance.insert('projects', {
        'name': project['field_7234'],
        'address': project['field_7235'],
        'status': project['field_7236'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'baserow_id': baserowId,
        'sync_status': 'synced',
        'last_sync': DateTime.now().toIso8601String(),
        'needs_sync': 0,
      });
    }
  }

  /// Upsert job (insert or update)
  static Future<void> _upsertJob(Map<String, dynamic> job) async {
    final baserowId = job['id'] as int;
    final jobNumber = job['field_7237'] as String;
    
    // Check if exists
    final existing = await DatabaseService.instance.query(
      'plans', 
      where: 'baserow_id = ?', 
      whereArgs: [baserowId]
    );
    
    if (existing.isNotEmpty) {
      // Update existing
      await DatabaseService.instance.update('plans', {
        'job_number': jobNumber,
        'name': job['field_7238'],
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'last_sync': DateTime.now().toIso8601String(),
      }, existing.first['id']);
    } else {
      // Find project by job number prefix
      final projectName = jobNumber.split('.')[0]; // J1441
      final projects = await DatabaseService.instance.query(
        'projects', 
        where: 'name LIKE ?', 
        whereArgs: ['$projectName%']
      );
      
      if (projects.isNotEmpty) {
        await DatabaseService.instance.insert('plans', {
          'project_id': projects.first['id'],
          'job_number': jobNumber,
          'name': job['field_7238'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'baserow_id': baserowId,
          'sync_status': 'synced',
          'last_sync': DateTime.now().toIso8601String(),
          'needs_sync': 0,
        });
      }
    }
  }

  /// Upsert plan (insert or update)
  static Future<void> _upsertPlan(Map<String, dynamic> plan) async {
    final baserowId = plan['id'] as int;
    final jobNumber = plan['field_7242'] as String;
    
    // Find local job
    final jobs = await DatabaseService.instance.query(
      'plans', 
      where: 'job_number = ?', 
      whereArgs: [jobNumber]
    );
    
    if (jobs.isNotEmpty) {
      final jobId = jobs.first['id'] as int;
      
      // Check if plan exists
      final existing = await DatabaseService.instance.query(
        'plan_images', 
        where: 'baserow_id = ?', 
        whereArgs: [baserowId]
      );
      
      if (existing.isNotEmpty) {
        // Update existing
        await DatabaseService.instance.update('plan_images', {
          'job_id': jobId,
          'image_path': plan['field_7243'],
          'name': plan['field_7244'],
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'synced',
          'last_sync': DateTime.now().toIso8601String(),
        }, existing.first['id']);
      } else {
        // Insert new
        await DatabaseService.instance.insert('plan_images', {
          'job_id': jobId,
          'image_path': plan['field_7243'],
          'name': plan['field_7244'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'baserow_id': baserowId,
          'sync_status': 'synced',
          'last_sync': DateTime.now().toIso8601String(),
          'needs_sync': 0,
        });
      }
    }
  }

  /// Queue local change for sync
  static Future<void> queueChange(String action, Map<String, dynamic> data) async {
    await DatabaseService.instance.insert('pending_changes', {
      'action': action,
      'data': json.encode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
    print('📝 Queued change: $action');
  }
}

