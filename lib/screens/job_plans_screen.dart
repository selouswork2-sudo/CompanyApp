import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
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
    final maps = await DatabaseService.instance.query(
      'plan_images',
      where: 'plan_id = ?',
      whereArgs: [widget.planId],
    );
    setState(() {
      _planImages = maps.map((e) => PlanImage.fromMap(e)).toList();
      _isLoading = false;
    });
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
    final XFile? image = await picker.pickImage(source: source);

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

              final planImage = PlanImage(
                planId: widget.planId,
                imagePath: imagePath,
                name: nameController.text,
                createdAt: DateTime.now(),
              );

              await DatabaseService.instance
                  .insert('plan_images', planImage.toMap());
              
              if (context.mounted) {
                Navigator.pop(context);
                _loadPlanImages();
              }
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
              await DatabaseService.instance.delete('plan_images', planImage.id!);
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
              : GridView.builder(
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
                              child: Image.file(
                                File(planImage.imagePath),
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
                              ),
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
      );
    }
  }

