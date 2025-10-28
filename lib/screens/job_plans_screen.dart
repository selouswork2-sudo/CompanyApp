import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/baserow_service.dart';
import '../models/plan_image.dart';
import 'plan_viewer_screen.dart';

class JobPlansScreen extends StatefulWidget {
  final String jobNumber;
  final String? jobName;
  final int planId;

  const JobPlansScreen({
    super.key,
    required this.jobNumber,
    this.jobName,
    required this.planId,
  });

  @override
  State<JobPlansScreen> createState() => _JobPlansScreenState();
}

class _JobPlansScreenState extends State<JobPlansScreen> {
  List<PlanImage> _planImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlanImages();
  }

  Future<void> _loadPlanImages() async {
    setState(() {
      _isLoading = true;
    });
    
    // First, find local job_id from job_number
    final jobs = await DatabaseService.instance.query(
      'plans',
      where: 'job_number = ?',
      whereArgs: [widget.jobNumber],
    );
    
    if (jobs.isEmpty) {
      print('⚠️ No job found with job_number: ${widget.jobNumber}');
      setState(() {
        _planImages = [];
        _isLoading = false;
      });
      return;
    }
    
    final localJobId = jobs.first['id'] as int;
    
    // Then query plan_images by job_id
    final maps = await DatabaseService.instance.query(
      'plan_images',
      where: 'job_id = ?',
      whereArgs: [localJobId],
    );
    
    setState(() {
      _planImages = maps.map((e) => PlanImage.fromMap(e)).toList();
      _isLoading = false;
    });
    
    print('📋 Loaded ${_planImages.length} plan images for job_number: ${widget.jobNumber}');
  }

  Widget _buildImageWidget(String imagePath) {
    // Try to display from local path first, then fallback to network
    if (imagePath.startsWith('/') || !imagePath.startsWith('http')) {
      // Local file path - try to display it
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If local file doesn't exist, it's probably a network URL that needs to be loaded
          // Since we don't have a network URL here, show placeholder
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              size: 50,
              color: Colors.grey,
            ),
          );
        },
      );
    } else {
      // Network URL (from Baserow)
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              size: 50,
              color: Colors.grey,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }
  }

  Future<String?> _downloadAndCacheImage(String url) async {
    try {
      // Create cache directory
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/plan_images');
      if (!await imageCacheDir.exists()) {
        await imageCacheDir.create(recursive: true);
      }

      // Generate filename from URL
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.last;
      final cachedFile = File('${imageCacheDir.path}/$filename');

      // Check if already cached
      if (await cachedFile.exists()) {
        return cachedFile.path;
      }

      // Download image
      print('🔄 Downloading image from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Save to cache
        await cachedFile.writeAsBytes(response.bodyBytes);
        print('✅ Image cached: ${cachedFile.path}');
        return cachedFile.path;
      } else {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading image: $e');
      return null;
    }
  }

  Future<void> _addPlanImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70, // Compress images to 70% quality for faster upload
    );

    if (image == null) return;

    if (mounted) {
      _showNameDialog(image.path);
    }
  }

  void _showNameDialog(String imagePath) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plan Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g., First Floor, Section A',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                return;
              }

              // Get the job's Baserow ID and job number from the plans table
              final jobMaps = await DatabaseService.instance.query(
                'plans',
                where: 'id = ?',
                whereArgs: [widget.planId],
              );
              
              if (jobMaps.isEmpty) {
                print('❌ Job not found with ID: ${widget.planId}');
                return;
              }
              
              final jobBaserowId = jobMaps.first['baserow_id'] as int?;
              final jobNumber = jobMaps.first['job_number'] as String?;
              
              if (jobNumber == null) {
                print('❌ Job has no job number: ${widget.planId}');
                return;
              }

              // STEP 1: Save immediately with local path (OPTIMISTIC UI)
              // Get local job_id (integer) from plans table
              final localJobId = jobMaps.first['id'] as int;
              
              final planData = {
                'job_id': localJobId,  // INTEGER - foreign key to plans table
                'image_path': imagePath,  // LOCAL PATH - shows thumbnail immediately!
                'name': nameController.text,
                'created_at': DateTime.now().toIso8601String(),
              };
              
              await SyncService.createPlanLocally(planData);
              
              if (context.mounted) {
                Navigator.pop(context);
                _loadPlanImages();
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan added (uploading in background...)')),
                );
              }
              
              // STEP 2: Upload to Baserow in background and update URL
              print('📤 Uploading plan image to Baserow in background...');
              final uploadedUrl = await BaserowService.uploadFile(imagePath);
              
              if (uploadedUrl == null) {
                print('❌ Failed to upload plan image to Baserow');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upload failed, will retry later')),
                  );
                }
                return;
              }
              
              print('✅ Plan image uploaded to Baserow: $uploadedUrl');
              
              // Update local database with uploaded URL
              final planImages = await DatabaseService.instance.query(
                'plan_images',
                where: 'job_id = ? AND name = ?',
                whereArgs: [localJobId, nameController.text],  // Use localJobId (integer), not jobNumber (string)
              );
              
              if (planImages.isNotEmpty) {
                await DatabaseService.instance.update(
                  'plan_images',
                  {'image_path': uploadedUrl},
                  planImages.first['id'],
                );
                print('✅ Updated plan image path with Baserow URL');
              } else {
                print('⚠️ No plan image found to update with URL');
              }
              
              // Sync to Baserow
              await SyncService.performFullSync();
              print('✅ Background sync completed after plan upload');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deletePlanImage(PlanImage planImage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete "${planImage.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Use SyncService to delete plan locally and queue for sync
              final planData = {
                'id': planImage.id,
                'baserow_id': planImage.baserowId,
                'job_id': planImage.jobId,
                'image_path': planImage.imagePath,
                'name': planImage.name,
              };
              
              await SyncService.deletePlanLocally(planData);
              
              // Trigger background sync immediately
              SyncService.performFullSync().then((_) {
                print('✅ Background sync completed after plan deletion');
              }).catchError((error) {
                print('⚠️ Background sync failed: $error');
              });
              
              // Delete file
              try {
                final file = File(planImage.imagePath);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                // Ignore file deletion errors
              }
              if (mounted) {
                _loadPlanImages();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Go back to building detail instead of closing app
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.jobNumber, style: const TextStyle(fontSize: 18)),
              if (widget.jobName != null && widget.jobName!.isNotEmpty)
                Text(
                  widget.jobName!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addPlanImage,
            ),
          ],
        ),
        body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _planImages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No plans yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add a plan',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Trigger sync when user pulls to refresh
                    await SyncService.performFullSync();
                    // Reload the plan images after sync
                    await _loadPlanImages();
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _planImages.length,
                    itemBuilder: (context, index) {
                      final planImage = _planImages[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlanViewerScreen(
                                planImages: _planImages,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _deletePlanImage(planImage),
                        child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildImageWidget(planImage.imagePath),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.white,
                              child: Text(
                                planImage.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ),
    );
  }
}

