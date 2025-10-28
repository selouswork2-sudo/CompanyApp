import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../models/plan_image.dart';
import '../models/pin.dart';
import '../models/pin_comment.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/baserow_service.dart';
import 'pin_detail_screen.dart';

class _PhotoCategorySelector extends StatefulWidget {
  final List<XFile> photos;
  final Function(List<Map<String, dynamic>>) onSave;
  final VoidCallback onCancel;

  const _PhotoCategorySelector({
    required this.photos,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_PhotoCategorySelector> createState() => _PhotoCategorySelectorState();
}

class _PhotoCategorySelectorState extends State<_PhotoCategorySelector> {
  final Map<int, String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    // Initialize all photos with 'before' category
    for (int i = 0; i < widget.photos.length; i++) {
      _selectedCategories[i] = 'before';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'before':
        return Colors.green;
      case 'during':
        return Colors.orange;
      case 'after':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Categories (${widget.photos.length} photos)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              final List<Map<String, dynamic>> result = [];
              for (int i = 0; i < widget.photos.length; i++) {
                result.add({
                  'path': widget.photos[i].path,
                  'category': _selectedCategories[i] ?? 'before',
                });
              }
              widget.onSave(result);
            },
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final selectedCategory = _selectedCategories[index] ?? 'before';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // Photo preview
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image, color: Colors.grey, size: 64),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Category selection buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCategoryButton(
                          'before',
                          'Before',
                          selectedCategory == 'before',
                          () => setState(() => _selectedCategories[index] = 'before'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryButton(
                          'during',
                          'During',
                          selectedCategory == 'during',
                          () => setState(() => _selectedCategories[index] = 'during'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryButton(
                          'after',
                          'After',
                          selectedCategory == 'after',
                          () => setState(() => _selectedCategories[index] = 'after'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryButton(String category, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _getCategoryColor(category) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _getCategoryColor(category) : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class PlanViewerScreen extends StatefulWidget {
  final List<PlanImage> planImages;
  final int initialIndex;

  const PlanViewerScreen({
    super.key,
    required this.planImages,
    required this.initialIndex,
  });

  @override
  State<PlanViewerScreen> createState() => _PlanViewerScreenState();
}

class _PlanViewerScreenState extends State<PlanViewerScreen> {
  late int _currentIndex;
  List<Pin> _pins = [];
  Pin? _draggingPin;
  bool _isLoading = true;
  Map<int, List<Map<String, dynamic>>> _pinPhotos = {}; // pinId -> list of photo objects
  bool _showMenu = false;
  String _currentMode = 'normal'; // normal, add, move, delete
  Pin? _pinToDelete;
  final ScrollController _pinListController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadPins();
  }

  @override
  void dispose() {
    _pinListController.dispose();
    super.dispose();
  }

  Future<void> _loadPins() async {
    if (widget.planImages.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final currentPlanImage = widget.planImages[_currentIndex];
    final maps = await DatabaseService.instance.query(
      'pins',
      where: 'plan_image_id = ?',
      whereArgs: [currentPlanImage.id],
    );
    
    setState(() {
      _pins = maps.map((e) => Pin.fromMap(e)).toList();
      _isLoading = false;
    });
    
    // Load photos for each pin
    await _loadPinPhotos();
  }

  Future<void> _loadPinPhotos() async {
    for (final pin in _pins) {
      final photos = <Map<String, dynamic>>[];
      
      // Parse before pictures (prioritize local, then URL)
      if (pin.beforePicturesLocal != null && pin.beforePicturesLocal!.isNotEmpty) {
        final localPaths = pin.beforePicturesLocal!.split(',');
        for (final path in localPaths) {
          if (path.trim().isNotEmpty) {
            photos.add({'image_path': path.trim(), 'category': 'before', 'is_url': false});
          }
        }
      } else if (pin.beforePicturesUrls != null && pin.beforePicturesUrls!.isNotEmpty) {
        final beforeUrls = pin.beforePicturesUrls!.split(',');
        for (final url in beforeUrls) {
          if (url.trim().isNotEmpty) {
            photos.add({'image_path': url.trim(), 'category': 'before', 'is_url': true});
          }
        }
      }
      
      // Parse during pictures (prioritize local, then URL)
      if (pin.duringPicturesLocal != null && pin.duringPicturesLocal!.isNotEmpty) {
        final localPaths = pin.duringPicturesLocal!.split(',');
        for (final path in localPaths) {
          if (path.trim().isNotEmpty) {
            photos.add({'image_path': path.trim(), 'category': 'during', 'is_url': false});
          }
        }
      } else if (pin.duringPicturesUrls != null && pin.duringPicturesUrls!.isNotEmpty) {
        final duringUrls = pin.duringPicturesUrls!.split(',');
        for (final url in duringUrls) {
          if (url.trim().isNotEmpty) {
            photos.add({'image_path': url.trim(), 'category': 'during', 'is_url': true});
          }
        }
      }
      
      // Parse after pictures (prioritize local, then URL)
      if (pin.afterPicturesLocal != null && pin.afterPicturesLocal!.isNotEmpty) {
        final localPaths = pin.afterPicturesLocal!.split(',');
        for (final path in localPaths) {
          if (path.trim().isNotEmpty) {
            photos.add({'image_path': path.trim(), 'category': 'after', 'is_url': false});
          }
        }
      } else if (pin.afterPicturesUrls != null && pin.afterPicturesUrls!.isNotEmpty) {
        final afterUrls = pin.afterPicturesUrls!.split(',');
        for (final url in afterUrls) {
          if (url.trim().isNotEmpty) {
            photos.add({'image_path': url.trim(), 'category': 'after', 'is_url': true});
          }
        }
      }
      
      setState(() {
        _pinPhotos[pin.id!] = photos;
      });
    }
  }

  Future<void> _addPin(double x, double y) async {
    if (widget.planImages.isEmpty) return;
    
    final currentPlanImage = widget.planImages[_currentIndex];
    final newPin = Pin(
      id: DateTime.now().millisecondsSinceEpoch,
      planImageId: currentPlanImage.id!,
      x: x,
      y: y,
      title: 'Pin ${_pins.length + 1}',
      createdAt: DateTime.now(),
    );

    // Use SyncService to create pin locally and queue for sync
    await SyncService.createPinLocally(newPin.toMap());
    
    // Trigger background sync immediately
    SyncService.performFullSync().then((_) {
      print('✅ Background sync completed after pin creation');
    }).catchError((error) {
      print('⚠️ Background sync failed: $error');
    });
    
    setState(() {
      _pins.add(newPin);
      _currentMode = 'normal'; // Reset mode after adding
    });
  }

  void _setMode(String mode) {
    setState(() {
      // If clicking the same mode, toggle to normal
      if (_currentMode == mode) {
        _currentMode = 'normal';
      } else {
        _currentMode = mode;
      }
      _showMenu = false;
      _pinToDelete = null;
    });
  }

  void _showDeleteConfirmation(Pin pin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pin'),
        content: Text('Are you sure you want to delete "${pin.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePin(pin);
              _setMode('normal');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePin(Pin pin) async {
    // Use SyncService to delete and sync to Baserow
    await SyncService.deletePinLocally(pin.id!);
    await SyncService.performFullSync();
    print('✅ Sync completed after pin deletion');
    
    // Reload all pins (including renumbering)
    await _loadPins();
    print('✅ Pins reloaded from database');
    
    // Renumber remaining pins
    await _renumberPins();
  }

  Future<void> _renumberPins() async {
    if (_pins.isEmpty) return;

    // Sort pins by created_at to maintain consistent ordering
    final sortedPins = List<Pin>.from(_pins)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Renumber pins starting from 1
    for (int i = 0; i < sortedPins.length; i++) {
      final currentPin = sortedPins[i];
      final newTitle = 'Pin ${i + 1}';

      // Only update if the title has changed
      if (currentPin.title != newTitle) {
        // Get latest pin data from database to ensure we have all fields
        final currentPinData = await DatabaseService.instance.query(
          'pins',
          where: 'id = ?',
          whereArgs: [currentPin.id],
        );

        if (currentPinData.isEmpty) continue;

        final dbPin = Pin.fromMap(currentPinData.first);

    final updatedPin = Pin(
          id: dbPin.id,
          planImageId: dbPin.planImageId,
          x: dbPin.x,
          y: dbPin.y,
          title: newTitle, // ← NEW TITLE
          description: dbPin.description,
          assignedTo: dbPin.assignedTo,
          status: dbPin.status,
          createdAt: dbPin.createdAt,
          beforePicturesUrls: dbPin.beforePicturesUrls,
          duringPicturesUrls: dbPin.duringPicturesUrls,
          afterPicturesUrls: dbPin.afterPicturesUrls,
          beforePicturesLocal: dbPin.beforePicturesLocal,
          duringPicturesLocal: dbPin.duringPicturesLocal,
          afterPicturesLocal: dbPin.afterPicturesLocal,
          baserowId: dbPin.baserowId,
          syncStatus: dbPin.syncStatus,
          lastSync: dbPin.lastSync,
          needsSync: dbPin.needsSync,
        );

        // Update locally and sync to Baserow
        await SyncService.updatePinLocally(updatedPin.toMap());
      }
    }

    // Sync all renumbered pins to Baserow
    await SyncService.performFullSync();
    print('✅ Pins renumbered and synced to Baserow');

    // Reload pins to reflect changes
    await _loadPins();
  }

  Future<void> _updatePinPosition(Pin pin, double newX, double newY) async {
    // Get latest pin data from database to ensure we have baserow_id and photo URLs
    final currentPinData = await DatabaseService.instance.query(
          'pins',
      where: 'id = ?',
      whereArgs: [pin.id],
    );
    
    if (currentPinData.isEmpty) {
      print('⚠️ Pin not found in database: ${pin.id}');
      return;
    }
    
    final currentPin = Pin.fromMap(currentPinData.first);
    
    final updatedPin = Pin(
      id: currentPin.id,
      planImageId: currentPin.planImageId,
      x: newX,
      y: newY,
      title: currentPin.title,
      description: currentPin.description,
      assignedTo: currentPin.assignedTo,
      status: currentPin.status,
      createdAt: currentPin.createdAt,
      beforePicturesUrls: currentPin.beforePicturesUrls,
      duringPicturesUrls: currentPin.duringPicturesUrls,
      afterPicturesUrls: currentPin.afterPicturesUrls,
      beforePicturesLocal: currentPin.beforePicturesLocal,
      duringPicturesLocal: currentPin.duringPicturesLocal,
      afterPicturesLocal: currentPin.afterPicturesLocal,
      baserowId: currentPin.baserowId,
      syncStatus: currentPin.syncStatus,
      lastSync: currentPin.lastSync,
      needsSync: currentPin.needsSync,
    );

    // Use SyncService to update locally and sync to Baserow
    await SyncService.updatePinLocally(updatedPin.toMap());
    await SyncService.performFullSync();
    print('✅ Sync completed after pin move');
    await _loadPins();
    print('✅ Pins reloaded from database');
  }

  Future<void> _addPhotoToPin(Pin pin) async {
    // Check if running on Windows
    final isWindows = Platform.isWindows;
    
    List<XFile> pickedFiles = [];
    
    if (isWindows) {
      // For Windows, use file picker to select images
      final picker = ImagePicker();
      pickedFiles = await picker.pickMultiImage(
        imageQuality: 70, // Compress images to 70% quality for faster upload
      );
    } else {
      // For mobile platforms, show source selection
    final String? source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery (Single)'),
              onTap: () => Navigator.pop(context, 'gallery_single'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery (Multiple)'),
              onTap: () => Navigator.pop(context, 'gallery_multiple'),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();

      if (source == 'gallery_multiple') {
          pickedFiles = await picker.pickMultiImage(
            imageQuality: 70, // Compress images to 70% quality for faster upload
          );
      } else if (source == 'gallery_single') {
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70, // Compress images to 70% quality for faster upload
          );
        if (pickedFile != null) {
          pickedFiles = [pickedFile];
        }
      } else if (source == 'camera') {
          final pickedFile = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 70, // Compress images to 70% quality for faster upload
          );
        if (pickedFile != null) {
          pickedFiles = [pickedFile];
          }
        }
        }
      }

    if (pickedFiles.isEmpty) return;

        // Show photo preview with category selection
        final List<Map<String, dynamic>> photoCategories = await _showPhotoCategorySelector(pickedFiles);
        
    if (photoCategories.isEmpty) return;

    try {
      // Organize photos by category
      final beforePhotos = <String>[];
      final duringPhotos = <String>[];
      final afterPhotos = <String>[];
      
          for (final photoData in photoCategories) {
        final path = photoData['path'] as String;
        final category = photoData['category'] as String;
        
        if (category == 'before') {
          beforePhotos.add(path);
        } else if (category == 'during') {
          duringPhotos.add(path);
        } else if (category == 'after') {
          afterPhotos.add(path);
        }
      }
      
      // Get current pin from database to preserve baserow_id and existing URLs/local paths
      final currentPinData = await DatabaseService.instance.query(
        'pins',
        where: 'id = ?',
        whereArgs: [pin.id],
      );
      final currentPin = Pin.fromMap(currentPinData.first);
      
      // STEP 1: Immediately save local paths and show thumbnails (OPTIMISTIC UI)
      final mergedBeforeLocal = _mergeUrls(currentPin.beforePicturesLocal ?? '', beforePhotos);
      final mergedDuringLocal = _mergeUrls(currentPin.duringPicturesLocal ?? '', duringPhotos);
      final mergedAfterLocal = _mergeUrls(currentPin.afterPicturesLocal ?? '', afterPhotos);
      
      // Update pin with local paths only (for instant thumbnail display)
      final pinWithLocalPaths = Pin(
        id: currentPin.id,
        planImageId: currentPin.planImageId,
        x: currentPin.x,
        y: currentPin.y,
        title: currentPin.title,
        description: currentPin.description,
        assignedTo: currentPin.assignedTo,
        status: currentPin.status,
        createdAt: currentPin.createdAt,
        beforePicturesUrls: currentPin.beforePicturesUrls, // Keep existing URLs
        duringPicturesUrls: currentPin.duringPicturesUrls,
        afterPicturesUrls: currentPin.afterPicturesUrls,
        beforePicturesLocal: mergedBeforeLocal.isNotEmpty ? mergedBeforeLocal : null,
        duringPicturesLocal: mergedDuringLocal.isNotEmpty ? mergedDuringLocal : null,
        afterPicturesLocal: mergedAfterLocal.isNotEmpty ? mergedAfterLocal : null,
        baserowId: currentPin.baserowId,
        syncStatus: currentPin.syncStatus,
        lastSync: currentPin.lastSync,
        needsSync: currentPin.needsSync,
      );
      
      // Save locally and refresh UI immediately (shows local thumbnails)
      await SyncService.updatePinLocally(pinWithLocalPaths.toMap());
      await _loadPins();
      print('✅ Local thumbnails displayed immediately');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${photoCategories.length} photo${photoCategories.length > 1 ? 's' : ''} added to pin')),
        );
      }
      
      // STEP 2: Upload to Baserow in background and update URLs
      print('📤 Uploading ${photoCategories.length} photos to Baserow in background...');
      
      // Show upload progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Text('Uploading ${beforePhotos.length + duringPhotos.length + afterPhotos.length} photo(s) to server...'),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Upload in background (don't await - let it run async)
      _uploadPhotosInBackground(pin.id!, beforePhotos, duringPhotos, afterPhotos, currentPin);
      
    } catch (e) {
      print('❌ Failed to add photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add photos: $e')),
        );
      }
    }
  }
  
  // Background upload method (runs async without blocking UI)
  Future<void> _uploadPhotosInBackground(
    int pinId,
    List<String> beforePhotos,
    List<String> duringPhotos,
    List<String> afterPhotos,
    Pin currentPin,
  ) async {
    try {
      String? beforeUrls;
      String? duringUrls;
      String? afterUrls;
      
      if (beforePhotos.isNotEmpty) {
        beforeUrls = await BaserowService.uploadMultipleFiles(beforePhotos);
      }
      if (duringPhotos.isNotEmpty) {
        duringUrls = await BaserowService.uploadMultipleFiles(duringPhotos);
      }
      if (afterPhotos.isNotEmpty) {
        afterUrls = await BaserowService.uploadMultipleFiles(afterPhotos);
      }
      
      // Merge new URLs with existing ones
      final mergedBeforeUrls = _mergeUrls(currentPin.beforePicturesUrls ?? '', [beforeUrls ?? '']);
      final mergedDuringUrls = _mergeUrls(currentPin.duringPicturesUrls ?? '', [duringUrls ?? '']);
      final mergedAfterUrls = _mergeUrls(currentPin.afterPicturesUrls ?? '', [afterUrls ?? '']);
      
      // Get latest pin data (might have been updated during upload)
      final latestPinData = await DatabaseService.instance.query(
        'pins',
        where: 'id = ?',
        whereArgs: [pinId],
      );
      final latestPin = Pin.fromMap(latestPinData.first);
      
      // Update with URLs (keeping local paths)
      final pinWithUrls = Pin(
        id: latestPin.id,
        planImageId: latestPin.planImageId,
        x: latestPin.x,
        y: latestPin.y,
        title: latestPin.title,
        description: latestPin.description,
        assignedTo: latestPin.assignedTo,
        status: latestPin.status,
        createdAt: latestPin.createdAt,
        beforePicturesUrls: mergedBeforeUrls.isNotEmpty ? mergedBeforeUrls : null,
        duringPicturesUrls: mergedDuringUrls.isNotEmpty ? mergedDuringUrls : null,
        afterPicturesUrls: mergedAfterUrls.isNotEmpty ? mergedAfterUrls : null,
        beforePicturesLocal: latestPin.beforePicturesLocal, // Keep local paths
        duringPicturesLocal: latestPin.duringPicturesLocal,
        afterPicturesLocal: latestPin.afterPicturesLocal,
        baserowId: latestPin.baserowId,
        syncStatus: latestPin.syncStatus,
        lastSync: latestPin.lastSync,
        needsSync: latestPin.needsSync,
      );
      
      // Update with URLs and sync to Baserow
      await SyncService.updatePinLocally(pinWithUrls.toMap());
      await SyncService.performFullSync();
      print('✅ Background upload completed and synced to Baserow');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear the "Uploading..." message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Text('Photos uploaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh UI to show uploaded status
        await _loadPins();
      }
    } catch (e) {
      print('❌ Background upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(child: Text('Upload failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  String _mergeUrls(String existing, List<String> newUrls) {
    final existingList = existing.isEmpty ? <String>[] : existing.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final newList = newUrls.where((e) => e.isNotEmpty).toList();
    final merged = [...existingList, ...newList];
    return merged.join(',');
  }

  Color _getPinColor(Pin pin) {
    if (_draggingPin?.id == pin.id) {
      return Colors.orange;
    }
    if (_currentMode == 'move') {
      return Colors.purple;
    }
    if (_currentMode == 'delete') {
      return Colors.red;
    }
    
    // Check if pin has all categories
    final pinPhotos = _pinPhotos[pin.id] ?? [];
    final categories = pinPhotos.map((photo) => photo['category'] as String).toSet();
    
    if (_currentMode == 'normal') {
      // Normal mode: show category status
      if (categories.containsAll(['before', 'during', 'after'])) {
        return Colors.green; // Complete - all categories present
      } else if (categories.isNotEmpty) {
        return Colors.orange; // Partial - some categories missing
      } else {
        return Colors.grey; // Empty - no photos
      }
    }
    
    return Colors.blue;
  }

  Color _getModeColor() {
    switch (_currentMode) {
      case 'add':
        return Colors.green;
      case 'move':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getModeText() {
    switch (_currentMode) {
      case 'add':
        return 'ADD MODE';
      case 'move':
        return 'MOVE MODE';
      case 'delete':
        return 'DELETE MODE';
      default:
        return 'NORMAL';
    }
  }

  IconData _getModeIcon() {
    switch (_currentMode) {
      case 'add':
        return Icons.add;
      case 'move':
        return Icons.open_with;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.menu;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'before':
        return Colors.green;
      case 'during':
        return Colors.orange;
      case 'after':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<List<Map<String, dynamic>>> _showPhotoCategorySelector(List<XFile> pickedFiles) async {
    final List<Map<String, dynamic>> photoCategories = [];
    
    return await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: _PhotoCategorySelector(
          photos: pickedFiles,
          onSave: (categories) {
            Navigator.pop(context, categories);
          },
          onCancel: () {
            Navigator.pop(context, <Map<String, dynamic>>[]);
          },
        ),
      ),
    ) ?? <Map<String, dynamic>>[];
  }

  void _scrollToPin(Pin pin) {
    final pinIndex = _pins.indexWhere((p) => p.id == pin.id);
    if (pinIndex != -1 && _pinListController.hasClients) {
      // Use scrollToIndex for more accurate positioning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pinListController.hasClients) {
          // Calculate more accurate position based on actual item height
          final itemHeight = 140.0; // More accurate height including margins
          final targetPosition = pinIndex * itemHeight;
          
          // Ensure the pin is fully visible by adding some padding
          final maxScroll = _pinListController.position.maxScrollExtent;
          final adjustedPosition = targetPosition.clamp(0.0, maxScroll);
          
          _pinListController.animateTo(
            adjustedPosition,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showPhotoOptionsDialog(Pin pin, Map<String, dynamic> photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change Photo'),
              onTap: () {
                Navigator.pop(context);
                _showChangePhotoDialog(pin, photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Category'),
              onTap: () {
                Navigator.pop(context);
                _showEditCategoryDialog(pin, photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Photo', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeletePhotoDialog(pin, photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePhotoDialog(Pin pin, Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: Text('Are you sure you want to delete this ${photo['category']} photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(pin, photo);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Pin pin, Map<String, dynamic> photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Change Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: const Text('Before'),
              trailing: photo['category'] == 'before' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(context);
                _changePhotoCategory(pin, photo, 'before');
              },
            ),
            ListTile(
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: const Text('During'),
              trailing: photo['category'] == 'during' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(context);
                _changePhotoCategory(pin, photo, 'during');
              },
            ),
            ListTile(
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: const Text('After'),
              trailing: photo['category'] == 'after' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(context);
                _changePhotoCategory(pin, photo, 'after');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhotoCategory(Pin pin, Map<String, dynamic> photo, String newCategory) async {
    try {
      final imagePath = photo['image_path'] as String;
      final oldCategory = photo['category'] as String;
      final isUrl = photo['is_url'] as bool? ?? false;
      
      // Get current pin from database
      final currentPinData = await DatabaseService.instance.query(
        'pins',
        where: 'id = ?',
        whereArgs: [pin.id],
      );
      
      if (currentPinData.isEmpty) return;
      
      final currentPin = Pin.fromMap(currentPinData.first);
      
      // Remove from old category
      String? oldUrls;
      String? oldLocal;
      if (oldCategory == 'before') {
        oldUrls = currentPin.beforePicturesUrls;
        oldLocal = currentPin.beforePicturesLocal;
      } else if (oldCategory == 'during') {
        oldUrls = currentPin.duringPicturesUrls;
        oldLocal = currentPin.duringPicturesLocal;
      } else if (oldCategory == 'after') {
        oldUrls = currentPin.afterPicturesUrls;
        oldLocal = currentPin.afterPicturesLocal;
      }
      
      // Remove the image from old category
      final oldUrlsList = oldUrls?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != imagePath).toList() ?? [];
      final oldLocalList = oldLocal?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != imagePath).toList() ?? [];
      
      // Add to new category
      String? newUrls;
      String? newLocal;
      if (newCategory == 'before') {
        newUrls = currentPin.beforePicturesUrls;
        newLocal = currentPin.beforePicturesLocal;
      } else if (newCategory == 'during') {
        newUrls = currentPin.duringPicturesUrls;
        newLocal = currentPin.duringPicturesLocal;
      } else if (newCategory == 'after') {
        newUrls = currentPin.afterPicturesUrls;
        newLocal = currentPin.afterPicturesLocal;
      }
      
      final newUrlsList = newUrls?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];
      final newLocalList = newLocal?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];
      
      if (isUrl) {
        newUrlsList.add(imagePath);
      } else {
        newLocalList.add(imagePath);
      }
      
      // Create updated pin
      final updatedPin = Pin(
        id: currentPin.id,
        planImageId: currentPin.planImageId,
        x: currentPin.x,
        y: currentPin.y,
        title: currentPin.title,
        description: currentPin.description,
        assignedTo: currentPin.assignedTo,
        status: currentPin.status,
        createdAt: currentPin.createdAt,
        beforePicturesUrls: oldCategory == 'before' 
            ? (oldUrlsList.isEmpty ? null : oldUrlsList.join(','))
            : newCategory == 'before'
                ? (newUrlsList.isEmpty ? null : newUrlsList.join(','))
                : currentPin.beforePicturesUrls,
        duringPicturesUrls: oldCategory == 'during'
            ? (oldUrlsList.isEmpty ? null : oldUrlsList.join(','))
            : newCategory == 'during'
                ? (newUrlsList.isEmpty ? null : newUrlsList.join(','))
                : currentPin.duringPicturesUrls,
        afterPicturesUrls: oldCategory == 'after'
            ? (oldUrlsList.isEmpty ? null : oldUrlsList.join(','))
            : newCategory == 'after'
                ? (newUrlsList.isEmpty ? null : newUrlsList.join(','))
                : currentPin.afterPicturesUrls,
        beforePicturesLocal: oldCategory == 'before'
            ? (oldLocalList.isEmpty ? null : oldLocalList.join(','))
            : newCategory == 'before'
                ? (newLocalList.isEmpty ? null : newLocalList.join(','))
                : currentPin.beforePicturesLocal,
        duringPicturesLocal: oldCategory == 'during'
            ? (oldLocalList.isEmpty ? null : oldLocalList.join(','))
            : newCategory == 'during'
                ? (newLocalList.isEmpty ? null : newLocalList.join(','))
                : currentPin.duringPicturesLocal,
        afterPicturesLocal: oldCategory == 'after'
            ? (oldLocalList.isEmpty ? null : oldLocalList.join(','))
            : newCategory == 'after'
                ? (newLocalList.isEmpty ? null : newLocalList.join(','))
                : currentPin.afterPicturesLocal,
        baserowId: currentPin.baserowId,
        syncStatus: currentPin.syncStatus,
        lastSync: currentPin.lastSync,
        needsSync: currentPin.needsSync,
      );
      
      // Update locally and sync to Baserow
      await SyncService.updatePinLocally(updatedPin.toMap());
      await SyncService.performFullSync();
      
      // Reload pins
      await _loadPins();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo moved to $newCategory category')),
        );
        }
      } catch (e) {
      print('❌ Failed to change photo category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change category: $e')),
        );
      }
    }
  }

  Future<void> _showChangePhotoDialog(Pin pin, Map<String, dynamic> photo) async {
    // First select image source
    final String? source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      XFile? newPhoto;

      if (source == 'camera') {
        newPhoto = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70, // Compress images to 70% quality for faster upload
        );
      } else if (source == 'gallery') {
        newPhoto = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70, // Compress images to 70% quality for faster upload
        );
      }

      if (newPhoto != null) {
        try {
          // Update in database if it has an ID
          if (photo['id'] != null && newPhoto != null) {
            await DatabaseService.instance.update('pin_photos', {
              'image_path': newPhoto.path,
            }, photo['id']);
          }
          
          // Update local state
          setState(() {
            if (_pinPhotos.containsKey(pin.id)) {
              final photoIndex = _pinPhotos[pin.id!]!.indexWhere((p) => p['image_path'] == photo['image_path']);
              if (photoIndex != -1) {
                _pinPhotos[pin.id!]![photoIndex]['image_path'] = newPhoto?.path ?? '';
              }
            }
          });

      if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo changed successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to change photo: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _deletePhoto(Pin pin, Map<String, dynamic> photo) async {
    try {
      final imagePath = photo['image_path'] as String;
      final category = photo['category'] as String;
      final isUrl = photo['is_url'] as bool? ?? false;
      
      // Get current pin from database
      final currentPinData = await DatabaseService.instance.query(
        'pins',
        where: 'id = ?',
        whereArgs: [pin.id],
      );
      
      if (currentPinData.isEmpty) return;
      
      final currentPin = Pin.fromMap(currentPinData.first);
      
      // Remove from the appropriate category
      String? urls;
      String? local;
      if (category == 'before') {
        urls = currentPin.beforePicturesUrls;
        local = currentPin.beforePicturesLocal;
      } else if (category == 'during') {
        urls = currentPin.duringPicturesUrls;
        local = currentPin.duringPicturesLocal;
      } else if (category == 'after') {
        urls = currentPin.afterPicturesUrls;
        local = currentPin.afterPicturesLocal;
      }
      
      // Remove the image from the lists
      final urlsList = urls?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != imagePath).toList() ?? [];
      final localList = local?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e != imagePath).toList() ?? [];
      
      // Create updated pin
      final updatedPin = Pin(
        id: currentPin.id,
        planImageId: currentPin.planImageId,
        x: currentPin.x,
        y: currentPin.y,
        title: currentPin.title,
        description: currentPin.description,
        assignedTo: currentPin.assignedTo,
        status: currentPin.status,
        createdAt: currentPin.createdAt,
        beforePicturesUrls: category == 'before' 
            ? (urlsList.isEmpty ? null : urlsList.join(','))
            : currentPin.beforePicturesUrls,
        duringPicturesUrls: category == 'during'
            ? (urlsList.isEmpty ? null : urlsList.join(','))
            : currentPin.duringPicturesUrls,
        afterPicturesUrls: category == 'after'
            ? (urlsList.isEmpty ? null : urlsList.join(','))
            : currentPin.afterPicturesUrls,
        beforePicturesLocal: category == 'before'
            ? (localList.isEmpty ? null : localList.join(','))
            : currentPin.beforePicturesLocal,
        duringPicturesLocal: category == 'during'
            ? (localList.isEmpty ? null : localList.join(','))
            : currentPin.duringPicturesLocal,
        afterPicturesLocal: category == 'after'
            ? (localList.isEmpty ? null : localList.join(','))
            : currentPin.afterPicturesLocal,
        baserowId: currentPin.baserowId,
        syncStatus: currentPin.syncStatus,
        lastSync: currentPin.lastSync,
        needsSync: currentPin.needsSync,
      );
      
      // Update locally and sync to Baserow
      await SyncService.updatePinLocally(updatedPin.toMap());
      await SyncService.performFullSync();
      
      // Reload pins
      await _loadPins();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      }
    } catch (e) {
      print('❌ Failed to delete photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete photo: $e')),
        );
      }
    }
  }

  void _showFullScreenImage(String imagePath, {bool isUrl = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
          child: Stack(
        children: [
            // Full screen image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: isUrl
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.white, size: 64),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.white, size: 64),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
          Positioned(
              top: 50,
              right: 20,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                    onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ),
            // Share button
            Positioned(
              top: 50,
              left: 20,
                child: Container(
                  decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    // Share functionality can be added here
                  },
                  icon: const Icon(Icons.share, color: Colors.white, size: 30),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = index == 1; // Projects is selected when on this screen
    
    return GestureDetector(
      onTap: () {
        // Navigate to the correct route
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/projects');
            break;
          case 2:
            context.go('/timesheet');
            break;
          case 3:
            context.go('/photos');
            break;
          case 4:
            context.go('/team');
            break;
        }
      },
            child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.planImages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan Viewer')),
        body: const Center(child: Text('No plan images available')),
        bottomNavigationBar: SafeArea(
            child: Container(
              decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Navigation items will be added here
                ],
              ),
      ),
      ),
      ),
    );
  }

    final currentPlanImage = widget.planImages[_currentIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final planHeight = screenHeight * 0.5; // Plan takes upper half

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan: ${currentPlanImage.name ?? 'Untitled'}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Plan Image Section (Upper Half)
          Container(
            height: planHeight,
            width: double.infinity,
            color: Colors.grey[100],
            child: Stack(
              children: [
                // Plan Image with Zoom and Pins
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Stack(
                    children: [
                      // Plan Image
                      GestureDetector(
            onTapDown: (details) {
                          if (_currentMode == 'add') {
                            // Get the plan image container bounds
                            final RenderBox? planBox = context.findRenderObject() as RenderBox?;
                            if (planBox != null) {
                              final localPosition = planBox.globalToLocal(details.globalPosition);
                              
                              // Calculate relative position within the plan container
                              final newX = (localPosition.dx / planBox.size.width).clamp(0.0, 1.0);
                              final newY = (localPosition.dy / planBox.size.height).clamp(0.0, 1.0);
                              
                              _addPin(newX, newY);
                            }
                          }
                        },
              child: Center(
                          child: currentPlanImage.imagePath.startsWith('http://') || currentPlanImage.imagePath.startsWith('https://')
                              ? Image.network(
                                  currentPlanImage.imagePath,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Icon(Icons.image, color: Colors.white, size: 64),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[800],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(currentPlanImage.imagePath),
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Icon(Icons.image, color: Colors.white, size: 64),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      
                      // Pins on the image (inside InteractiveViewer)
                      ..._pins.map((pin) => Positioned(
                        left: (pin.x * MediaQuery.of(context).size.width - 15).clamp(0.0, MediaQuery.of(context).size.width - 30),
                        top: (pin.y * planHeight - 15).clamp(0.0, planHeight - 30),
                        child: GestureDetector(
                          onTap: () {
                            if (_currentMode == 'delete') {
                              _showDeleteConfirmation(pin);
                            } else if (_currentMode == 'normal') {
                              // Scroll to pin in the list
                              _scrollToPin(pin);
                            }
                          },
                          onPanStart: (details) {
                            if (_currentMode == 'move') {
                              setState(() {
                                _draggingPin = pin;
                              });
                            }
                          },
                          onPanUpdate: (details) {
                            if (_currentMode == 'move' && _draggingPin?.id == pin.id) {
                              // Use the pin's current position as offset to prevent jumping
                              final currentPin = _pins.firstWhere((p) => p.id == pin.id);
                              final deltaX = details.delta.dx / MediaQuery.of(context).size.width;
                              final deltaY = details.delta.dy / planHeight;
                              
                              final newX = (currentPin.x + deltaX).clamp(0.0, 1.0);
                              final newY = (currentPin.y + deltaY).clamp(0.0, 1.0);
                              
                              setState(() {
                                final index = _pins.indexWhere((p) => p.id == pin.id);
                                if (index != -1) {
                                  _pins[index] = Pin(
                                  id: pin.id,
                                  planImageId: pin.planImageId,
                                    x: newX,
                                    y: newY,
                                  title: pin.title,
                                  description: pin.description,
                                  assignedTo: pin.assignedTo,
                                  status: pin.status,
                                  createdAt: pin.createdAt,
                                );
                                }
                              });
                            }
                          },
                          onPanEnd: (details) {
                            if (_draggingPin != null && _draggingPin!.id == pin.id && _currentMode == 'move') {
                              // Save final position to database
                              final finalPin = _pins.firstWhere((p) => p.id == pin.id);
                              _updatePinPosition(finalPin, finalPin.x, finalPin.y);
                              _draggingPin = null;
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _draggingPin?.id == pin.id ? 40 : 30,
                            height: _draggingPin?.id == pin.id ? 40 : 30,
                  decoration: BoxDecoration(
                              color: _getPinColor(pin),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _draggingPin?.id == pin.id ? Colors.yellow : Colors.white, 
                                width: _draggingPin?.id == pin.id ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(_draggingPin?.id == pin.id ? 0.6 : 0.3),
                                  blurRadius: _draggingPin?.id == pin.id ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_pins.indexOf(pin) + 1}',
                                    style: TextStyle(
                      color: Colors.white,
                                      fontSize: _draggingPin?.id == pin.id ? 16 : 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // Show category status indicator
                                  if (_currentMode == 'normal' && _draggingPin?.id != pin.id) ...[
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Before indicator
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: (_pinPhotos[pin.id] ?? [])
                                                .any((photo) => photo['category'] == 'before')
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        // During indicator
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: (_pinPhotos[pin.id] ?? [])
                                                .any((photo) => photo['category'] == 'during')
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        // After indicator
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: (_pinPhotos[pin.id] ?? [])
                                                .any((photo) => photo['category'] == 'after')
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                    ),
                  ),
                ),
                        ),
                      )),
                    ],
              ),
            ),

                // Pin Control Menu (Bottom Right)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      // Close menu when tapping outside
                      if (_showMenu) {
        setState(() {
                          _showMenu = false;
                        });
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mode Indicator
                        if (_currentMode != 'normal')
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getModeColor(),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getModeText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        
                        // Menu Button
                        FloatingActionButton(
                          onPressed: () {
      setState(() {
                              _showMenu = !_showMenu;
                            });
                          },
                          backgroundColor: _currentMode != 'normal' ? _getModeColor() : Colors.blue,
                          child: Icon(
                            _getModeIcon(),
                            color: Colors.white,
                          ),
                        ),
                        
                        // Menu Items
                        if (_showMenu) ...[
                          const SizedBox(height: 10),
                          // Add Pin
                          FloatingActionButton.small(
                            onPressed: () => _setMode('add'),
                            backgroundColor: _currentMode == 'add' ? Colors.green[700] : Colors.green,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          // Move Pin
                          FloatingActionButton.small(
                            onPressed: () => _setMode('move'),
                            backgroundColor: _currentMode == 'move' ? Colors.orange[700] : Colors.orange,
                            child: const Icon(Icons.open_with, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          // Delete Pin
                          FloatingActionButton.small(
                            onPressed: () => _setMode('delete'),
                            backgroundColor: _currentMode == 'delete' ? Colors.red[700] : Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          // Normal Mode
                          FloatingActionButton.small(
                            onPressed: () => _setMode('normal'),
                            backgroundColor: _currentMode == 'normal' ? Colors.blue[700] : Colors.blue,
                            child: const Icon(Icons.touch_app, color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pin List Section (Lower Half)
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _pinListController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _pins.length,
                      itemBuilder: (context, index) {
                        final pin = _pins[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Pin Number
                                Container(
                                  width: 40,
                                  height: 40,
      decoration: BoxDecoration(
                                    color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
                                      '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
                                        fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Photo Grid (Scrollable) - Sorted by category
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
          child: Row(
            children: [
                                        // Show photos sorted by category: before, during, after
                                        ...['before', 'during', 'after'].expand((category) {
                                          final categoryPhotos = (_pinPhotos[pin.id] ?? [])
                                              .where((photo) => photo['category'] == category)
                                              .toList();
                                          
                                          return categoryPhotos.map((photo) {
                                            return GestureDetector(
                                              onTap: () => _showFullScreenImage(photo['image_path'], isUrl: photo['is_url'] == true),
                                              onLongPress: () => _showPhotoOptionsDialog(pin, photo),
                                              child: Container(
                                                width: 50,
                                                height: 50,
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _getCategoryColor(photo['category']),
                                                    width: 3,
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: (photo['is_url'] == true)
                                                      ? Image.network(
                                                          photo['image_path'],
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              color: Colors.grey[300],
                                                              child: const Icon(Icons.image, color: Colors.grey, size: 20),
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
                                                        )
                                                      : Image.file(
                                                    File(photo['image_path']),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: Colors.grey[300],
                                                        child: const Icon(Icons.image, color: Colors.grey, size: 20),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          });
                                        }),
                                        
                                        // Add Photo Button (always visible)
                                        Container(
                                          width: 50,
                                          height: 50,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                          child: IconButton(
                                            onPressed: () => _addPhotoToPin(pin),
                                            icon: const Icon(Icons.add, color: Colors.grey, size: 20),
                                            padding: EdgeInsets.zero,
                ),
              ),
            ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                _buildNavItem(1, Icons.business, 'Projects'),
                _buildNavItem(2, Icons.access_time, 'TimeSheet'),
                _buildNavItem(3, Icons.photo_camera, 'Photos'),
                _buildNavItem(4, Icons.people, 'Team'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}