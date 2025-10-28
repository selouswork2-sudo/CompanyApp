import 'dart:convert';
import '../models/project.dart';
import '../models/plan.dart';
import 'database_service.dart';
import 'baserow_service.dart';

class SyncService {
  static const String _pendingChangesTable = 'pending_changes';
  static const String _lastSyncKey = 'last_sync_time';
  static bool _isSyncing = false; // Add sync lock

  /// Perform full bidirectional sync
  static Future<SyncResult> performFullSync() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      print('⚠️ Sync already in progress, skipping...');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        projectsSynced: 0,
        changesUploaded: 0,
      );
    }
    
    _isSyncing = true;

    try {
      print('🔄 Starting full bidirectional sync...');
      
      // 1. Upload pending changes first
      int changesUploaded = await _uploadPendingChanges();
      
      // 2. Download fresh data from Baserow
      await _downloadFromBaserow();
      
      // 3. Update sync timestamp
      await _setLastSyncTime(DateTime.now());
      
      print('✅ Full sync completed: $changesUploaded changes uploaded');
      
      return SyncResult(
        success: true,
        message: 'Sync completed successfully',
        projectsSynced: 0,
        changesUploaded: changesUploaded,
      );
      
    } catch (e) {
      print('❌ Full sync failed: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        projectsSynced: 0,
        changesUploaded: 0,
      );
    } finally {
      _isSyncing = false; // Release sync lock
    }
  }

  /// Upload all pending changes to Baserow
  static Future<int> _uploadPendingChanges() async {
    final pendingChanges = await _getPendingChanges();
    print('🔄 Found ${pendingChanges.length} pending changes to upload');
    
    int uploaded = 0;
    for (final change in pendingChanges) {
      try {
        await _uploadChange(change);
        await _removePendingChange(change['id']);
        uploaded++;
        print('✅ Successfully uploaded change: ${change['action']}');
      } catch (e) {
        // Check if it's a 404 (item not found in Baserow - probably already deleted)
        final errorMessage = e.toString();
        if (errorMessage.contains('404') || errorMessage.contains('not found')) {
          print('⚠️ Item not found in Baserow (404) - removing from pending changes');
          await _removePendingChange(change['id']);
        } else if (errorMessage.contains('500')) {
          print('❌ Server error (500) - keeping in pending changes for retry');
          print('❌ Change that failed: ${change['action']} - ${change['data']}');
        } else {
          print('❌ Failed to upload change: $e');
          print('❌ Change that failed: ${change['action']} - ${change['data']}');
        }
      }
    }
    
    return uploaded;
  }

  /// Upload a single change to Baserow
  static Future<void> _uploadChange(Map<String, dynamic> change) async {
    final action = change['action'] as String;
    final dataString = change['data'] as String;
    
    print('🔄 DEBUG: Raw data string: "$dataString"');
    print('🔄 DEBUG: Data string type: ${dataString.runtimeType}');
    
    try {
      Map<String, dynamic> data;
      
      // Check if the data is in old format (string representation of Map)
      if (dataString.startsWith('{') && dataString.contains('=') && !dataString.contains('"')) {
        print('🔄 DEBUG: Detected old format, converting...');
        // Convert old format to proper JSON
        final convertedString = dataString
            .replaceAll('=', '":')
            .replaceAll(', ', ', "')
            .replaceAll('{', '{"');
        print('🔄 DEBUG: Converted string: "$convertedString"');
        data = Map<String, dynamic>.from(json.decode(convertedString));
      } else {
        // Try to parse as normal JSON
        data = Map<String, dynamic>.from(json.decode(dataString));
      }
      
      print('🔄 DEBUG: Parsed data: $data');
    
    print('🔄 Uploading pending change: $action');
    print('  Data: $data');
    
    switch (action) {
      case 'create':
          // Filter out fields that don't exist in Baserow
          final cleanData = <String, dynamic>{};
          if (data.containsKey('name')) cleanData['name'] = data['name'];
          if (data.containsKey('address')) cleanData['address'] = data['address'];
          if (data.containsKey('status')) cleanData['status'] = data['status'];
          // Don't send: start_date, end_date, description, id, baserow_id, sync_status, last_sync, needs_sync, created_at, updated_at
          
          final response = await BaserowService.createProject(cleanData);
          // Update local project with Baserow ID
          final baserowId = response['id'];
          if (baserowId != null && data['id'] != null) {
            await DatabaseService.instance.update('projects', {
              'baserow_id': baserowId,
              'sync_status': 'synced',
              'needs_sync': 0,
              'last_sync': DateTime.now().toIso8601String(),
            }, data['id']);
            print('✅ Updated local project with Baserow ID: $baserowId');
          } else {
            print('⚠️ Cannot update local project: baserowId=$baserowId, localId=${data['id']}');
          }
        break;
          
      case 'update':
        final baserowId = data['baserow_id'];
        if (baserowId != null) {
          // Filter out fields that don't exist in Baserow
          final cleanData = <String, dynamic>{};
          if (data.containsKey('name')) cleanData['name'] = data['name'];
          if (data.containsKey('address')) cleanData['address'] = data['address'];
          if (data.containsKey('status')) cleanData['status'] = data['status'];
          // Don't send: start_date, end_date, description, id, baserow_id, sync_status, last_sync, needs_sync, created_at, updated_at
          
          await BaserowService.updateProject(baserowId, cleanData);
            // Mark as synced
            if (data['id'] != null) {
              await DatabaseService.instance.update('projects', {
                'sync_status': 'synced',
                'needs_sync': 0,
                'last_sync': DateTime.now().toIso8601String(),
              }, data['id']);
            }
        } else {
          print('⚠️ Cannot update project: no Baserow ID found');
        }
        break;
          
      case 'delete':
        final baserowId = data['baserow_id'];
        if (baserowId != null) {
          await BaserowService.deleteProject(baserowId);
        } else {
          print('⚠️ Cannot delete project: no Baserow ID found');
        }
        break;
          
        case 'create_job':
          final response = await BaserowService.createJob(data);
          // Update local job with Baserow ID
          final baserowId = response['id'];
          if (baserowId != null && data['id'] != null) {
            await DatabaseService.instance.update('plans', {
              'baserow_id': baserowId,
              'sync_status': 'synced',
              'needs_sync': 0,
              'last_sync': DateTime.now().toIso8601String(),
            }, data['id']);
            print('✅ Updated local job with Baserow ID: $baserowId');
          } else {
            print('⚠️ Cannot update local job: baserowId=$baserowId, localId=${data['id']}');
          }
          break;
          
        case 'update_job':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.updateJob(baserowId, data);
            // Mark as synced
            if (data['id'] != null) {
              await DatabaseService.instance.update('plans', {
                'sync_status': 'synced',
                'needs_sync': 0,
                'last_sync': DateTime.now().toIso8601String(),
              }, data['id']);
            }
          } else {
            print('⚠️ Cannot update job: no Baserow ID found');
          }
          break;
          
        case 'delete_job':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.deleteJob(baserowId);
          } else {
            print('⚠️ Cannot delete job: no Baserow ID found');
          }
          break;
          
        case 'create_plan':
          // Get the latest plan data from database (includes uploaded URL)
          final localPlan = await DatabaseService.instance.query(
            'plan_images',
            where: 'id = ?',
            whereArgs: [data['id']],
          );
          
          if (localPlan.isEmpty) {
            print('⚠️ Plan not found locally, skipping sync');
            break;
          }
          
          // Use the latest image_path from database (which should be URL after background upload)
          data['image_path'] = localPlan.first['image_path'];
          print('🔄 Using latest image_path from database: ${data['image_path']}');
          
          // Get job_number from job_id
          final jobId = localPlan.first['job_id'];
          if (jobId != null) {
            final jobs = await DatabaseService.instance.query(
              'plans',
              where: 'id = ?',
              whereArgs: [jobId],
            );
            
            if (jobs.isNotEmpty) {
              data['job_number'] = jobs.first['job_number'];
              print('🔄 Found job_number for plan image: ${data['job_number']}');
            }
          }
          
          final response = await BaserowService.createPlanImage(data);
          final baserowId = response['id'];
          
          if (baserowId != null && data['id'] != null) {
            await DatabaseService.instance.update('plan_images', {
              'baserow_id': baserowId,
              'sync_status': 'synced',
              'needs_sync': 0,
              'last_sync': DateTime.now().toIso8601String(),
            }, data['id']);
            print('✅ Updated local plan with Baserow ID: $baserowId');
          } else {
            print('⚠️ Cannot update local plan: baserowId=$baserowId, localId=${data['id']}');
          }
          break;
          
        case 'update_plan':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.updatePlanImage(baserowId, data);
            // Mark as synced
            if (data['id'] != null) {
              await DatabaseService.instance.update('plan_images', {
                'sync_status': 'synced',
                'needs_sync': 0,
                'last_sync': DateTime.now().toIso8601String(),
              }, data['id']);
            }
          } else {
            print('⚠️ Cannot update plan: no Baserow ID found');
          }
          break;
          
        case 'delete_plan':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.deletePlanImage(baserowId);
          } else {
            print('⚠️ Cannot delete plan: no Baserow ID found');
          }
          break;

        // Photos actions
        case 'create_photo':
          final response = await BaserowService.createPhoto(data);
          final baserowId = response['id'];
          if (baserowId != null && data['id'] != null) {
            await DatabaseService.instance.update('plan_images', {
              'baserow_id': baserowId,
              'sync_status': 'synced',
              'needs_sync': 0,
              'last_sync': DateTime.now().toIso8601String(),
            }, data['id']);
            print('✅ Updated local photo with Baserow ID: $baserowId');
          }
          break;

        case 'update_photo':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.updatePhoto(baserowId, data);
            if (data['id'] != null) {
              await DatabaseService.instance.update('plan_images', {
                'sync_status': 'synced',
                'needs_sync': 0,
                'last_sync': DateTime.now().toIso8601String(),
              }, data['id']);
            }
          } else {
            print('⚠️ Cannot update photo: no Baserow ID found');
          }
          break;

        case 'delete_photo':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.deletePhoto(baserowId);
          } else {
            print('⚠️ Cannot delete photo: no Baserow ID found');
          }
          break;

        case 'delete_plan':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.deletePlanImage(baserowId);
          } else {
            print('⚠️ Cannot delete plan: no Baserow ID found');
          }
          break;

        // Pins actions
        case 'create_pin':
          // Get job_number AND plan_image_name from plan_image_id
          final planImageId = data['plan_image_id'];
          if (planImageId != null) {
            final planImages = await DatabaseService.instance.query(
              'plan_images',
              where: 'id = ?',
              whereArgs: [planImageId],
            );
            
            if (planImages.isNotEmpty) {
              final planImageName = planImages.first['name'] as String?;
              final jobId = planImages.first['job_id'];
              
              if (jobId != null) {
                final jobs = await DatabaseService.instance.query(
                  'plans',
                  where: 'id = ?',
                  whereArgs: [jobId],
                );
                
                if (jobs.isNotEmpty) {
                  data['job_number'] = jobs.first['job_number'];
                  print('🔄 Found job_number for pin: ${data['job_number']}');
                  
                  // Add plan_name to the data for Baserow
                  if (planImageName != null) {
                    data['plan_name'] = planImageName;
                    print('🔄 Found plan_name for pin: $planImageName');
                  }
                }
              }
            }
          }
          
          // Filter out local-only fields before sending to Baserow
          print('🔍 DEBUG: data before filtering: $data');
          print('🔍 DEBUG: data[\'plan_name\'] before filtering: ${data['plan_name']}');
          final baserowData = Map<String, dynamic>.from(data);
          baserowData.remove('before_pictures_local');
          baserowData.remove('during_pictures_local');
          baserowData.remove('after_pictures_local');
          baserowData.remove('id');
          baserowData.remove('plan_image_id');
          baserowData.remove('baserow_id');
          baserowData.remove('sync_status');
          baserowData.remove('last_sync');
          baserowData.remove('needs_sync');
          baserowData.remove('description');
          baserowData.remove('assigned_to');
          baserowData.remove('status');
          baserowData.remove('created_at');
          
          final response = await BaserowService.createPin(baserowData);
          final baserowId = response['id'];
          if (baserowId != null && data['id'] != null) {
            await DatabaseService.instance.update('pins', {
              'baserow_id': baserowId,
              'sync_status': 'synced',
              'needs_sync': 0,
              'last_sync': DateTime.now().toIso8601String(),
            }, data['id']);
            print('✅ Updated local pin with Baserow ID: $baserowId');
          }
          break;

        case 'update_pin':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            // Get job_number AND plan_image_name from plan_image_id (if not already in data)
            if (!data.containsKey('job_number') || !data.containsKey('plan_name')) {
              final planImageId = data['plan_image_id'];
              if (planImageId != null) {
                final planImages = await DatabaseService.instance.query(
                  'plan_images',
                  where: 'id = ?',
                  whereArgs: [planImageId],
                );
                
                if (planImages.isNotEmpty) {
                  final planImageName = planImages.first['name'] as String?;
                  final jobId = planImages.first['job_id'];
                  
                  if (jobId != null && !data.containsKey('job_number')) {
                    final jobs = await DatabaseService.instance.query(
                      'plans',
                      where: 'id = ?',
                      whereArgs: [jobId],
                    );
                    
                    if (jobs.isNotEmpty) {
                      data['job_number'] = jobs.first['job_number'];
                      print('🔄 Found job_number for pin update: ${data['job_number']}');
                    }
                  }
                  
                  if (planImageName != null && !data.containsKey('plan_name')) {
                    data['plan_name'] = planImageName;
                    print('🔄 Found plan_image_name for pin update: $planImageName');
                  }
                }
              }
            }
            
            // Filter out local-only fields before sending to Baserow
            final baserowData = Map<String, dynamic>.from(data);
            baserowData.remove('before_pictures_local');
            baserowData.remove('during_pictures_local');
            baserowData.remove('after_pictures_local');
            baserowData.remove('id');
            baserowData.remove('plan_image_id');
            baserowData.remove('baserow_id');
            baserowData.remove('sync_status');
            baserowData.remove('last_sync');
            baserowData.remove('needs_sync');
            baserowData.remove('description');
            baserowData.remove('assigned_to');
            baserowData.remove('status');
            baserowData.remove('created_at');
            
            await BaserowService.updatePin(baserowId, baserowData);
            if (data['id'] != null) {
              await DatabaseService.instance.update('pins', {
                'sync_status': 'synced',
                'needs_sync': 0,
                'last_sync': DateTime.now().toIso8601String(),
              }, data['id']);
            }
          } else {
            print('⚠️ Cannot update pin: no Baserow ID found');
          }
          break;

        case 'delete_pin':
          final baserowId = data['baserow_id'];
          if (baserowId != null) {
            await BaserowService.deletePin(baserowId);
          } else {
            print('⚠️ Cannot delete pin: no Baserow ID found');
          }
          break;
    }
    
    print('✅ Pending change uploaded successfully');
    } catch (e) {
      print('❌ JSON parsing error: $e');
      print('❌ Raw data that failed to parse: "$dataString"');
      rethrow;
    }
  }

  /// Download projects from Baserow
  static Future<void> _downloadFromBaserow() async {
    try {
      final baserowProjects = await BaserowService.getProjects();
      print('📥 Downloaded ${baserowProjects.length} projects from Baserow');
      
      // Get existing local projects
      final localProjects = await DatabaseService.instance.query('projects');
      final existingBaserowIds = localProjects.map((p) => p['baserow_id']).where((id) => id != null).cast<int>().toSet();
      final existingNames = localProjects.map((p) => p['name'] as String).toSet();
      
      // Process Baserow projects
      int added = 0;
      int updated = 0;
      
      for (final baserowProject in baserowProjects) {
        final baserowId = baserowProject['id'] as int;
        // Updated field IDs per new schema: name=7454, address=7455, status=7456, created_at=7458
        final projectName = baserowProject['field_7454'] ?? '';
        
        if (projectName.isEmpty) continue; // Skip projects without names
        
        // Check if we already have this project by Baserow ID
        if (existingBaserowIds.contains(baserowId)) {
          // Update existing project
          final localProject = localProjects.firstWhere(
            (p) => p['baserow_id'] == baserowId,
            orElse: () => throw Exception('Project with Baserow ID $baserowId not found'),
          );
          
          final projectMap = {
            'name': projectName,
            'address': baserowProject['field_7455'] ?? '',
            'status': BaserowService.convertStatusFromBaserowFormat(baserowProject['field_7456']),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };
          
          await DatabaseService.instance.update('projects', projectMap, localProject['id']);
          updated++;
          print('🔄 Updated existing project from Baserow: $projectName');
          
        } else if (existingNames.contains(projectName)) {
          // Project exists locally but doesn't have Baserow ID - link them
          final localProject = localProjects.firstWhere((p) => p['name'] == projectName);
          await DatabaseService.instance.update('projects', {
            'baserow_id': baserowId,
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          }, localProject['id']);
          print('🔄 Linked existing project "$projectName" with Baserow ID: $baserowId');
        } else {
          // Add new project (only if name doesn't exist)
          final projectMap = {
            'name': projectName,
            'address': baserowProject['field_7455'] ?? '',
            'status': BaserowService.convertStatusFromBaserowFormat(baserowProject['field_7456']),
            'created_at': baserowProject['field_7458'] ?? DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'baserow_id': baserowId,
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };
          
          await DatabaseService.instance.insert('projects', projectMap);
          added++;
          print('🔄 Added new project from Baserow: $projectName');
        }
      }
      
      print('✅ Sync completed: $added new projects added, $updated projects updated');
      
      // Also sync jobs
      await _downloadJobsFromBaserow();
      
      // Also sync plans
      await _downloadPlansFromBaserow();
      
      // Also sync pins
      await _downloadPinsFromBaserow();
      
    } catch (e) {
      print('❌ Failed to download from Baserow: $e');
    }
  }

  /// Download jobs from Baserow and sync with local database
  static Future<void> _downloadJobsFromBaserow() async {
    try {
      final baserowJobs = await BaserowService.getJobs();
      print('📥 Downloaded ${baserowJobs.length} jobs from Baserow');

      // Get existing local jobs
      final localJobs = await DatabaseService.instance.query('plans');
      final existingBaserowIds = localJobs.map((j) => j['baserow_id']).where((id) => id != null).cast<int>().toSet();
      final existingJobNumbers = localJobs.map((j) => j['job_number'] as String).toSet();

      // Process Baserow jobs
      int added = 0;
      int updated = 0;

      for (final baserowJob in baserowJobs) {
        final baserowId = baserowJob['id'] as int;
        // Updated field IDs per new schema: job_number=7463, name=7464
        final jobNumber = baserowJob['field_7463'] ?? '';
        final jobName = baserowJob['field_7464'] ?? '';

        if (jobNumber.isEmpty) continue; // Skip jobs without job numbers

        // Check if we already have this job by Baserow ID
        if (existingBaserowIds.contains(baserowId)) {
          // Update existing job
          final localJob = localJobs.firstWhere(
            (j) => j['baserow_id'] == baserowId,
            orElse: () => throw Exception('Job with Baserow ID $baserowId not found'),
          );

          final jobMap = {
            'job_number': jobNumber,
            'name': jobName,
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.update('plans', jobMap, localJob['id']);
          updated++;
          print('🔄 Updated existing job from Baserow: $jobNumber');

        } else if (!existingJobNumbers.contains(jobNumber)) {
          // Add new job (only if job number doesn't exist)
          final jobMap = {
            'project_id': 1, // Default project ID - you might want to handle this differently
            'job_number': jobNumber,
            'name': jobName,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'baserow_id': baserowId,
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.insert('plans', jobMap);
          added++;
          print('🔄 Added new job from Baserow: $jobNumber');
        } else {
          // Job number exists locally but no baserow_id yet - update with baserow_id
          final localJobWithoutBaserowId = localJobs.firstWhere(
            (j) => (j['job_number'] as String) == jobNumber && j['baserow_id'] == null,
            orElse: () => {},
          );
          
          if (localJobWithoutBaserowId.isNotEmpty) {
            // Update local job with Baserow ID
            final jobMap = {
              'baserow_id': baserowId,
              'name': jobName,
              'updated_at': DateTime.now().toIso8601String(),
              'sync_status': 'synced',
              'last_sync': DateTime.now().toIso8601String(),
              'needs_sync': 0,
            };
            
            await DatabaseService.instance.update('plans', jobMap, localJobWithoutBaserowId['id']);
            updated++;
            print('🔄 Linked local job to Baserow: $jobNumber (baserow_id: $baserowId)');
          } else {
            print('⚠️ Skipping job "$jobNumber" - job number already exists locally');
          }
        }
      }

      print('✅ Jobs sync completed: $added new jobs added, $updated jobs updated');

    } catch (e) {
      print('❌ Failed to download jobs from Baserow: $e');
    }
  }

  /// Download plans from Baserow and sync with local database
  static Future<void> _downloadPlansFromBaserow() async {
    try {
      final baserowPlans = await BaserowService.getPlanImages();
      print('📥 Downloaded ${baserowPlans.length} plans from Baserow');

      // Get existing local plans
      final localPlans = await DatabaseService.instance.query('plan_images');
      final existingBaserowIds = localPlans.map((p) => p['baserow_id']).where((id) => id != null).cast<int>().toSet();
      final existingNames = localPlans.map((p) => p['name'] as String).toSet();

      // Process Baserow plans
      int added = 0;
      int updated = 0;

      for (final baserowPlan in baserowPlans) {
        final baserowId = baserowPlan['id'] as int;
        // Updated field IDs per new schema: job_number=7470, image_path=7471, name=7472, created_at=7474
        final planName = baserowPlan['field_7472'] ?? '';
        final jobNumber = baserowPlan['field_7470'] ?? '';
        final imagePath = baserowPlan['field_7471'] ?? '';
        final createdAt = baserowPlan['field_7474'] ?? DateTime.now().toIso8601String();

        if (planName.isEmpty) continue; // Skip plans without names

        // Find local job ID by job number
        int? localJobId;
        if (jobNumber.isNotEmpty) {
          final localJobs = await DatabaseService.instance.query('plans', where: 'job_number = ?', whereArgs: [jobNumber]);
          if (localJobs.isNotEmpty) {
            localJobId = localJobs.first['id'] as int;
          }
        }

        if (localJobId == null) {
          print('⚠️ Skipping plan "$planName" - job number "$jobNumber" not found locally');
          continue;
        }

        // Check if we already have this plan by Baserow ID
        if (existingBaserowIds.contains(baserowId)) {
          // Update existing plan
          final localPlan = localPlans.firstWhere(
            (p) => p['baserow_id'] == baserowId,
            orElse: () => throw Exception('Plan with Baserow ID $baserowId not found'),
          );

          final planMap = {
            'job_id': localJobId,
            'image_path': imagePath,
            'name': planName,
            'created_at': createdAt,
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.update('plan_images', planMap, localPlan['id']);
          updated++;
          print('🔄 Updated existing plan from Baserow: $planName');

        } else if (!existingNames.contains(planName)) {
          // Add new plan (only if name doesn't exist)
          final planMap = {
            'job_id': localJobId,
            'image_path': imagePath,
            'name': planName,
            'created_at': createdAt,
            'updated_at': DateTime.now().toIso8601String(),
            'baserow_id': baserowId,
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.insert('plan_images', planMap);
          added++;
          print('🔄 Added new plan from Baserow: $planName');
        } else {
          print('⚠️ Skipping plan "$planName" - plan name already exists locally');
        }
      }

      print('✅ Plans sync completed: $added new plans added, $updated plans updated');

    } catch (e) {
      print('❌ Failed to download plans from Baserow: $e');
    }
  }

  /// Download pins from Baserow and sync with local database
  static Future<void> _downloadPinsFromBaserow() async {
    try {
      final baserowPins = await BaserowService.getPins();
      print('📥 Downloaded ${baserowPins.length} pins from Baserow');

      // Get existing local pins
      final localPins = await DatabaseService.instance.query('pins');
      final existingBaserowIds = localPins.map((p) => p['baserow_id']).where((id) => id != null).cast<int>().toSet();

      // Process Baserow pins
      int added = 0;
      int updated = 0;

      for (final baserowPin in baserowPins) {
        final baserowId = baserowPin['id'] as int;
        // Field IDs per new schema
        final jobNumber = baserowPin['field_7476'] ?? '';
        final planName = baserowPin['field_7477'] ?? '';
        final x = baserowPin['field_7478'] ?? '';
        final y = baserowPin['field_7479'] ?? '';
        final title = baserowPin['field_7480'] ?? '';
        final beforeUrls = baserowPin['field_7481'] ?? '';
        final duringUrls = baserowPin['field_7482'] ?? '';
        final afterUrls = baserowPin['field_7483'] ?? '';

        // Find local plan_image_id by job_number AND plan_name
        int? localPlanImageId;
        if (jobNumber.isNotEmpty && planName.isNotEmpty) {
          final localJobs = await DatabaseService.instance.query('plans', where: 'job_number = ?', whereArgs: [jobNumber]);
          print('🔍 Looking for job "$jobNumber" and plan "$planName" - found ${localJobs.length} jobs');
          
          if (localJobs.isNotEmpty) {
            final localJobId = localJobs.first['id'] as int;
            // Find the SPECIFIC plan_image by name
            final localPlans = await DatabaseService.instance.query('plan_images', where: 'job_id = ? AND name = ?', whereArgs: [localJobId, planName]);
            print('🔍 Found ${localPlans.length} plan images for job "$jobNumber" and plan "$planName"');
            
            if (localPlans.isNotEmpty) {
              localPlanImageId = localPlans.first['id'] as int;
              print('✅ Using plan_image_id: $localPlanImageId for job "$jobNumber" and plan "$planName"');
            }
          }
        }

        if (localPlanImageId == null) {
          print('⚠️ Skipping pin "$title" - job number "$jobNumber" not found locally');
          continue;
        }

        // Check if we already have this pin by Baserow ID
        if (existingBaserowIds.contains(baserowId)) {
          // Update existing pin
          final localPin = localPins.firstWhere(
            (p) => p['baserow_id'] == baserowId,
            orElse: () => throw Exception('Pin with Baserow ID $baserowId not found'),
          );

          final pinMap = {
            'plan_image_id': localPlanImageId,
            'x': double.tryParse(x.toString()) ?? 0.0,
            'y': double.tryParse(y.toString()) ?? 0.0,
            'title': title,
            'before_pictures_urls': beforeUrls.isEmpty ? null : beforeUrls,
            'during_pictures_urls': duringUrls.isEmpty ? null : duringUrls,
            'after_pictures_urls': afterUrls.isEmpty ? null : afterUrls,
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.update('pins', pinMap, localPin['id']);
          updated++;
          print('🔄 Updated existing pin from Baserow: $title');

        } else {
          // Add new pin
          final pinMap = {
            'plan_image_id': localPlanImageId,
            'x': double.tryParse(x.toString()) ?? 0.0,
            'y': double.tryParse(y.toString()) ?? 0.0,
            'title': title,
            'created_at': DateTime.now().toIso8601String(),
            'before_pictures_urls': beforeUrls.isEmpty ? null : beforeUrls,
            'during_pictures_urls': duringUrls.isEmpty ? null : duringUrls,
            'after_pictures_urls': afterUrls.isEmpty ? null : afterUrls,
            'baserow_id': baserowId,
            'sync_status': 'synced',
            'last_sync': DateTime.now().toIso8601String(),
            'needs_sync': 0,
          };

          await DatabaseService.instance.insert('pins', pinMap);
          added++;
          print('🔄 Added new pin from Baserow: $title');
        }
      }

      print('✅ Pins sync completed: $added new pins added, $updated pins updated');

    } catch (e) {
      print('❌ Failed to download pins from Baserow: $e');
    }
  }

  /// Create job locally and queue for sync
  static Future<void> createJobLocally(Plan job) async {
    final jobMap = job.toMap();
    jobMap['sync_status'] = 'pending';
    jobMap['needs_sync'] = 1;
    jobMap['last_sync'] = null;
    
    final insertedId = await DatabaseService.instance.insert('plans', jobMap);
    print('✅ Job created locally with ID: $insertedId');
    
    // Update the job with the inserted ID for sync
    jobMap['id'] = insertedId;
    await _savePendingChange('create_job', jobMap);
    print('✅ Job created locally and queued for sync');
  }

  /// Update job locally and queue for sync
  static Future<void> updateJobLocally(Plan job) async {
    print('🔄 updateJobLocally called for job: ${job.jobNumber}');
    
    if (job.id == null) {
      print('⚠️ Job has no ID, cannot sync update');
      return;
    }
    
    final jobMap = job.toMap();
    jobMap['sync_status'] = 'pending';
    jobMap['needs_sync'] = 1;
    jobMap['last_sync'] = null;
    
    await DatabaseService.instance.update('plans', jobMap, job.id!);
    await _savePendingChange('update_job', jobMap);
    print('✅ Job updated locally and queued for sync');
  }

  /// Delete job locally and queue for sync
  static Future<void> deleteJobLocally(Plan job) async {
    print('🔄 deleteJobLocally called for job: ${job.jobNumber}');
    
    if (job.id == null) {
      print('⚠️ Job has no ID, cannot sync delete');
      return;
    }
    
    // Queue delete for Baserow before deleting locally
    final jobMap = job.toMap();
    if (job.baserowId != null) {
      await _savePendingChange('delete_job', {'id': job.id, 'baserow_id': job.baserowId, 'job_number': job.jobNumber, 'name': job.name ?? ''});
    } else {
      print('⚠️ Job has no Baserow ID, deleted locally only');
    }
    
    // Delete locally
    await DatabaseService.instance.delete('plans', job.id!);
    print('✅ Job deleted locally and queued for sync');
  }

  /// Create project locally and queue for sync
  static Future<void> createProjectLocally(Project project) async {
    final projectMap = project.toMap();
    projectMap['sync_status'] = 'pending';
    projectMap['needs_sync'] = 1;
    projectMap['last_sync'] = null;
    
    final insertedId = await DatabaseService.instance.insert('projects', projectMap);
    print('✅ Project created locally with ID: $insertedId');
    
    // Update the project with the inserted ID for sync
    projectMap['id'] = insertedId;
    await _savePendingChange('create', projectMap);
    print('✅ Project created locally and queued for sync');
  }

  /// Update project locally and queue for sync
  static Future<void> updateProjectLocally(Project project) async {
    print('🔄 updateProjectLocally called for project: ${project.name}');
    
    // Get current project to find Baserow ID
    final currentProjects = await DatabaseService.instance.query('projects', where: 'id = ?', whereArgs: [project.id]);
    if (currentProjects.isNotEmpty) {
      final currentProject = currentProjects.first;
      final baserowId = currentProject['baserow_id'];
      
      if (baserowId != null) {
        final projectMap = project.toMap();
        projectMap['baserow_id'] = baserowId;
        projectMap['sync_status'] = 'pending';
        projectMap['needs_sync'] = 1;
        projectMap['last_sync'] = null;
        
        await DatabaseService.instance.update('projects', projectMap, project.id!);
        await _savePendingChange('update', projectMap);
        
        print('✅ Project updated locally and queued for sync');
      } else {
        print('⚠️ Project has no Baserow ID, cannot sync update');
      }
    }
  }

  /// Delete project locally and queue for sync
  static Future<void> deleteProjectLocally(int projectId) async {
    // Get project to find Baserow ID
    final projects = await DatabaseService.instance.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (projects.isNotEmpty) {
      final project = projects.first;
      final baserowId = project['baserow_id'];
      
      if (baserowId != null) {
        // First, queue cascade delete from Baserow
        await _deleteProjectCascadeFromBaserow(projectId, baserowId);
        
        // Queue project delete for Baserow
        await _savePendingChange('delete', {'id': projectId, 'baserow_id': baserowId});
        
        // Then delete locally
        await DatabaseService.instance.delete('projects', projectId);
        print('✅ Project deleted locally and queued for sync to Baserow');
      } else {
        // No Baserow ID, delete locally only
        await DatabaseService.instance.delete('projects', projectId);
        print('⚠️ Project has no Baserow ID, deleted locally only');
      }
    }
  }

  /// Delete all related data from Baserow when project is deleted
  static Future<void> _deleteProjectCascadeFromBaserow(int projectId, int projectBaserowId) async {
    try {
      print('🔄 Starting cascade delete for project ID: $projectId');
      
      // 1. Find all jobs (plans) for this project
      final jobs = await DatabaseService.instance.query('plans', where: 'project_id = ?', whereArgs: [projectId]);
      print('🔄 Found ${jobs.length} jobs to delete from Baserow');
      
      for (final job in jobs) {
        final jobBaserowId = job['baserow_id'] as int?;
        if (jobBaserowId != null) {
          // Delete job from Baserow
          await _savePendingChange('delete_job', {
            'id': job['id'],
            'baserow_id': jobBaserowId,
            'job_number': job['job_number'],
            'name': job['name'],
          });
          print('🔄 Queued job deletion: ${job['job_number']} (Baserow ID: $jobBaserowId)');
          
          // 2. Find all plans (plan_images) for this job
          final plans = await DatabaseService.instance.query('plan_images', where: 'job_id = ?', whereArgs: [job['id']]);
          print('🔄 Found ${plans.length} plans to delete from Baserow for job: ${job['job_number']}');
          
          for (final plan in plans) {
            final planBaserowId = plan['baserow_id'] as int?;
            if (planBaserowId != null) {
              // Delete plan from Baserow
              await _savePendingChange('delete_plan', {
                'id': plan['id'],
                'baserow_id': planBaserowId,
                'job_id': plan['job_id'],
                'name': plan['name'],
                'image_path': plan['image_path'],
              });
              print('🔄 Queued plan deletion: ${plan['name']} (Baserow ID: $planBaserowId)');
            }
          }
        }
      }
      
      print('✅ Cascade delete queued for project ID: $projectId');
    } catch (e) {
      print('❌ Error in cascade delete: $e');
    }
  }

  /// Save a pending change
  static Future<void> _savePendingChange(String action, Map<String, dynamic> data) async {
    print('🔄 DEBUG: Saving pending change - action: $action');
    print('🔄 DEBUG: Raw data to save: $data');
    
    final jsonString = json.encode(data);
    print('🔄 DEBUG: JSON string to store: "$jsonString"');
    
    final change = {
      'action': action,
      'data': jsonString, // Store as JSON string
      'created_at': DateTime.now().toIso8601String(),
    };
    
    print('🔄 DEBUG: Final change object: $change');
    
    await DatabaseService.instance.insert(_pendingChangesTable, change);
    print('✅ Pending change saved: $action');
  }

  /// Get all pending changes
  static Future<List<Map<String, dynamic>>> _getPendingChanges() async {
    return await DatabaseService.instance.query(_pendingChangesTable);
  }

  /// Get all pending changes (public method)
  static Future<List<Map<String, dynamic>>> getPendingChanges() async {
    return await _getPendingChanges();
  }

  /// Remove a pending change
  static Future<void> _removePendingChange(int changeId) async {
    await DatabaseService.instance.delete(_pendingChangesTable, changeId);
  }

  /// Set last sync time
  static Future<void> _setLastSyncTime(DateTime time) async {
    // Delete existing entry first, then insert new one
    final existing = await DatabaseService.instance.query('sync_settings', where: 'key = ?', whereArgs: [_lastSyncKey]);
    if (existing.isNotEmpty) {
      await DatabaseService.instance.delete('sync_settings', existing.first['id']);
    }
    await DatabaseService.instance.insert('sync_settings', {
      'key': _lastSyncKey,
      'value': time.toIso8601String(),
    });
  }

  /// Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final results = await DatabaseService.instance.query('sync_settings', where: 'key = ?', whereArgs: [_lastSyncKey]);
    if (results.isNotEmpty) {
      return DateTime.parse(results.first['value']);
    }
    return null;
  }

  /// Check if sync is needed
  static Future<bool> isSyncNeeded() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    
    final difference = DateTime.now().difference(lastSync);
    return difference.inMinutes > 2; // Sync every 2 minutes
  }

  /// Force immediate sync
  static Future<void> forceSync() async {
    await performFullSync();
  }

  /// Auto sync method for network service
  static Future<void> autoSync() async {
    await performFullSync();
  }

  /// Check and sync if needed
  static Future<void> checkAndSyncIfNeeded() async {
    if (await isSyncNeeded()) {
      await performFullSync();
    }
  }

  /// Clear all pending changes (for debugging)
  static Future<void> clearPendingChanges() async {
    final db = await DatabaseService.instance.database;
    await db.delete('pending_changes');
    print('✅ Cleared all pending changes');
  }

  /// Clear failed pending changes and force sync existing jobs
  static Future<void> clearFailedChangesAndSyncJobs() async {
    try {
      print('🔄 Clearing failed pending changes and syncing existing jobs...');
      
      // Clear all pending changes
      final db = await DatabaseService.instance.database;
      await db.delete('pending_changes');
      print('✅ Cleared all pending changes');
      
      // Find all local jobs that need to be synced
      final localJobs = await DatabaseService.instance.query('plans');
      int syncedJobs = 0;
      
      for (final job in localJobs) {
        final jobNumber = job['job_number'] as String?;
        final jobName = job['name'] as String?;
        final baserowId = job['baserow_id'] as int?;
        
        if (jobNumber != null && jobNumber.isNotEmpty && baserowId == null) {
          // This job exists locally but not in Baserow - create it
          try {
            final jobData = {
              'job_number': jobNumber,
              'name': jobName ?? jobNumber,
            };
            
            final response = await BaserowService.createJob(jobData);
            final newBaserowId = response['id'] as int;
            
            // Update local job with Baserow ID
            await DatabaseService.instance.update(
              'plans',
              {
                'baserow_id': newBaserowId,
                'sync_status': 'synced',
                'last_sync': DateTime.now().toIso8601String(),
                'needs_sync': 0,
              },
              job['id'] as int,
            );
            
            syncedJobs++;
            print('✅ Synced job "$jobNumber" to Baserow (ID: $newBaserowId)');
          } catch (e) {
            print('❌ Failed to sync job "$jobNumber": $e');
          }
        }
      }
      
      print('✅ Job sync completed: $syncedJobs jobs synced to Baserow');
      
    } catch (e) {
      print('❌ Error clearing failed changes and syncing jobs: $e');
    }
  }

  /// Force sync specific job by job number
  static Future<void> forceSyncJob(String jobNumber) async {
    try {
      print('🔄 Force syncing job: $jobNumber');
      
      // Find the job locally
      final localJobs = await DatabaseService.instance.query('plans', where: 'job_number = ?', whereArgs: [jobNumber]);
      
      if (localJobs.isEmpty) {
        print('❌ Job "$jobNumber" not found locally');
        return;
      }
      
      final job = localJobs.first;
      final baserowId = job['baserow_id'] as int?;
      
      if (baserowId != null) {
        print('✅ Job "$jobNumber" already has Baserow ID: $baserowId');
        return;
      }
      
      // Create job in Baserow
      final jobData = {
        'job_number': jobNumber,
        'name': job['name'] as String? ?? jobNumber,
      };
      
      final response = await BaserowService.createJob(jobData);
      final newBaserowId = response['id'] as int;
      
      // Update local job with Baserow ID
      await DatabaseService.instance.update(
        'plans',
        {
          'baserow_id': newBaserowId,
          'sync_status': 'synced',
          'last_sync': DateTime.now().toIso8601String(),
          'needs_sync': 0,
        },
        job['id'] as int,
      );
      
      print('✅ Successfully synced job "$jobNumber" to Baserow (ID: $newBaserowId)');
      
    } catch (e) {
      print('❌ Failed to force sync job "$jobNumber": $e');
    }
  }

  /// Create plan locally and queue for sync
  static Future<void> createPlanLocally(Map<String, dynamic> planData) async {
    // Add only the required fields
    final dataToInsert = Map<String, dynamic>.from(planData);
    dataToInsert['sync_status'] = 'pending';
    dataToInsert['needs_sync'] = 1;
    dataToInsert['last_sync'] = '';
    dataToInsert['created_at'] = DateTime.now().toIso8601String();
    dataToInsert['updated_at'] = DateTime.now().toIso8601String();
    
    final insertedId = await DatabaseService.instance.insert('plan_images', dataToInsert);
    print('✅ Plan created locally with ID: $insertedId');
    
    // Create a new map for sync with the inserted ID
    final syncData = Map<String, dynamic>.from(planData);
    syncData['id'] = insertedId;
    await _savePendingChange('create_plan', syncData);
    print('✅ Plan created locally and queued for sync');
  }

  /// Update plan locally and queue for sync
  static Future<void> updatePlanLocally(Map<String, dynamic> planData) async {
    planData['sync_status'] = 'pending';
    planData['needs_sync'] = 1;  // Back to int for database
    planData['updated_at'] = DateTime.now().toIso8601String();
    
    await DatabaseService.instance.update('plan_images', planData, planData['id']);
    await _savePendingChange('update_plan', planData);
    print('✅ Plan updated locally and queued for sync');
  }

  /// Delete plan locally and queue for sync
  static Future<void> deletePlanLocally(Map<String, dynamic> planData) async {
    // Queue deletion for Baserow before deleting locally
    final baserowId = planData['baserow_id'];
    if (baserowId != null) {
      await _savePendingChange('delete_plan', {'id': planData['id'], 'baserow_id': baserowId});
    } else {
      print('⚠️ Plan has no Baserow ID, deleted locally only');
    }
    
    // Delete locally
    await DatabaseService.instance.delete('plan_images', planData['id']);
    print('✅ Plan deleted locally and queued for sync');
  }

  /// Save pending change (public method)
  static Future<void> savePendingChange(String action, Map<String, dynamic> data) async {
    await _savePendingChange(action, data);
  }

  // ==================== PHOTOS SYNC ====================

  /// Create photo locally and queue for Baserow sync
  static Future<void> createPhotoLocally(Map<String, dynamic> photoData) async {
    try {
      // Insert into local database
      final id = await DatabaseService.instance.insert('plan_images', photoData);
      print('✅ Photo created locally with ID: $id');
      
      // Queue for Baserow sync
      photoData['id'] = id;
      await savePendingChange('create_photo', photoData);
      print('✅ Photo created locally and queued for sync');
    } catch (e) {
      print('❌ Failed to create photo locally: $e');
      rethrow;
    }
  }

  /// Update photo locally and queue for Baserow sync
  static Future<void> updatePhotoLocally(Map<String, dynamic> photoData) async {
    try {
      final id = photoData['id'];
      if (id == null) throw Exception('Photo ID is required for update');
      
      // Update in local database
      await DatabaseService.instance.update('plan_images', photoData, id);
      print('✅ Photo updated locally with ID: $id');
      
      // Queue for Baserow sync
      await savePendingChange('update_photo', photoData);
      print('✅ Photo update queued for sync');
    } catch (e) {
      print('❌ Failed to update photo locally: $e');
      rethrow;
    }
  }

  /// Delete photo locally and queue for Baserow sync
  static Future<void> deletePhotoLocally(int photoId) async {
    try {
      // Get photo data before deleting (to get Baserow ID)
      final photoData = await DatabaseService.instance.query(
        'plan_images',
        where: 'id = ?',
        whereArgs: [photoId],
      );
      
      if (photoData.isEmpty) {
        print('⚠️ Photo not found: $photoId');
        return;
      }
      
      final photo = photoData.first;
      final baserowId = photo['baserow_id'];
      
      // Delete from local database
      await DatabaseService.instance.delete('plan_images', photoId);
      print('✅ Photo deleted locally with ID: $photoId');
      
      // Queue for Baserow sync if has Baserow ID
      if (baserowId != null) {
        await savePendingChange('delete_photo', {
          'id': photoId,
          'baserow_id': baserowId,
        });
        print('✅ Photo deletion queued for sync');
      }
    } catch (e) {
      print('❌ Failed to delete photo locally: $e');
      rethrow;
    }
  }

  // ==================== PINS SYNC ====================

  /// Create pin locally and queue for Baserow sync
  static Future<void> createPinLocally(Map<String, dynamic> pinData) async {
    try {
      // Insert into local database
      final id = await DatabaseService.instance.insert('pins', pinData);
      print('✅ Pin created locally with ID: $id');
      
      // Queue for Baserow sync
      pinData['id'] = id;
      await savePendingChange('create_pin', pinData);
      print('✅ Pin created locally and queued for sync');
    } catch (e) {
      print('❌ Failed to create pin locally: $e');
      rethrow;
    }
  }

  /// Update pin locally and queue for Baserow sync
  static Future<void> updatePinLocally(Map<String, dynamic> pinData) async {
    try {
      final id = pinData['id'];
      if (id == null) throw Exception('Pin ID is required for update');
      
      // Update in local database
      await DatabaseService.instance.update('pins', pinData, id);
      print('✅ Pin updated locally with ID: $id');
      
      // Queue for Baserow sync
      await savePendingChange('update_pin', pinData);
      print('✅ Pin update queued for sync');
    } catch (e) {
      print('❌ Failed to update pin locally: $e');
      rethrow;
    }
  }

  /// Delete pin locally and queue for Baserow sync
  static Future<void> deletePinLocally(int pinId) async {
    try {
      // Get pin data before deleting (to get Baserow ID)
      final pinData = await DatabaseService.instance.query(
        'pins',
        where: 'id = ?',
        whereArgs: [pinId],
      );
      
      if (pinData.isEmpty) {
        print('⚠️ Pin not found: $pinId');
        return;
      }
      
      final pin = pinData.first;
      final baserowId = pin['baserow_id'];
      
      // Delete from local database
      await DatabaseService.instance.delete('pins', pinId);
      print('✅ Pin deleted locally with ID: $pinId');
      
      // Queue for Baserow sync if has Baserow ID
      if (baserowId != null) {
        await savePendingChange('delete_pin', {
          'id': pinId,
          'baserow_id': baserowId,
        });
        print('✅ Pin deletion queued for sync');
      }
    } catch (e) {
      print('❌ Failed to delete pin locally: $e');
      rethrow;
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int projectsSynced;
  final int changesUploaded;

  SyncResult({
    required this.success,
    required this.message,
    required this.projectsSynced,
    required this.changesUploaded,
  });
}