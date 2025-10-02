import 'dart:io';
import 'package:flutter/material.dart';
import '../models/plan_image.dart';
import '../models/pin.dart';
import '../services/database_service.dart';
import 'pin_detail_screen.dart';

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
  late PageController _pageController;
  late int _currentIndex;
  bool _showMenu = false;
  bool _annotateMode = false;
  bool _moveMode = false;
  bool _deleteMode = false;
  List<Pin> _pins = [];
  List<Pin> _allBuildingPins = []; // All pins in this building
  Pin? _selectedPinToMove;
  Pin? _draggingPin;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadPinsForBuilding();
    _loadPins();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadPins() async {
    final maps = await DatabaseService.instance.query(
      'pins',
      where: 'plan_image_id = ?',
      whereArgs: [widget.planImages[_currentIndex].id],
    );
    setState(() {
      _pins = maps.map((e) => Pin.fromMap(e)).toList();
    });
  }

  Future<void> _loadPinsForBuilding() async {
    // Get the first plan image's plan_id to find the project_id
    final planImageId = widget.planImages.first.planId;
    
    // Get the plan (job) to find project_id
    final planMaps = await DatabaseService.instance.query(
      'plans',
      where: 'id = ?',
      whereArgs: [planImageId],
    );
    
    if (planMaps.isEmpty) return;
    
    final projectId = planMaps.first['project_id'];
    
    // Get all plans (jobs) for this building
    final allPlansForBuilding = await DatabaseService.instance.query(
      'plans',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    
    // Collect all pins from all plan images in this building
    List<Pin> allPins = [];
    
    for (var plan in allPlansForBuilding) {
      // Get all plan images for this job
      final planImages = await DatabaseService.instance.query(
        'plan_images',
        where: 'plan_id = ?',
        whereArgs: [plan['id']],
      );
      
      // Get all pins for each plan image
      for (var planImage in planImages) {
        final pins = await DatabaseService.instance.query(
          'pins',
          where: 'plan_image_id = ?',
          whereArgs: [planImage['id']],
        );
        
        allPins.addAll(pins.map((e) => Pin.fromMap(e)));
      }
    }
    
    // Sort by creation date
    allPins.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    setState(() {
      _allBuildingPins = allPins;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _annotateMode = false;
      _moveMode = false;
      _deleteMode = false;
      _showMenu = false;
      _selectedPinToMove = null;
      _draggingPin = null;
    });
    _loadPinsForBuilding();
    _loadPins();
  }


  Future<void> _onPinTap(Pin pin, int pinNumber) async {
    if (_deleteMode) {
      // Delete pin
      _confirmDeletePin(pin, pinNumber);
    } else if (!_moveMode && !_annotateMode) {
      // Open pin detail (only if not in move/annotate mode)
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinDetailScreen(
            pin: pin,
            planImage: widget.planImages[_currentIndex],
            x: pin.x,
            y: pin.y,
            pinNumber: pinNumber,
          ),
        ),
      );

      if (result == true) {
        _loadPinsForBuilding(); // Reload building pins first
        _loadPins();
      }
    }
  }

  void _confirmDeletePin(Pin pin, int pinNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pin'),
        content: Text('Are you sure you want to delete Pin #$pinNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService.instance.delete('pins', pin.id!);
              _loadPinsForBuilding(); // Reload building pins first
              _loadPins();
              setState(() {
                _deleteMode = false;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlanImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete "${widget.planImages[_currentIndex].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final planImageToDelete = widget.planImages[_currentIndex];
      
      // Delete from database
      await DatabaseService.instance.delete('plan_images', planImageToDelete.id!);
      
      // Delete file
      try {
        final file = File(planImageToDelete.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore file deletion errors
      }

      if (mounted) {
        // If this was the last image, go back
        if (widget.planImages.length == 1) {
          Navigator.pop(context, true);
        } else {
          // Remove from list and update
          widget.planImages.removeAt(_currentIndex);
          if (_currentIndex >= widget.planImages.length) {
            _currentIndex = widget.planImages.length - 1;
          }
          _pageController.jumpToPage(_currentIndex);
          _loadPins();
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button - navigate back instead of closing app
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
        children: [
          // Image viewer with pins
          PageView.builder(
            controller: _pageController,
            itemCount: widget.planImages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildImageWithPins(index);
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.planImages[_currentIndex].name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1}/${widget.planImages.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // Mode indicators
          if (_annotateMode || _moveMode || _deleteMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _annotateMode 
                        ? Colors.orange 
                        : _moveMode 
                            ? Colors.blue 
                            : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _annotateMode 
                        ? 'Tap on plan to add pin' 
                        : _moveMode
                            ? 'Drag a pin to move it'
                            : 'Tap a pin to delete it',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom right menu button
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showMenu) ...[
                  _buildMenuButton(
                    Icons.pin_drop,
                    'Annotate',
                    () {
                      setState(() {
                        _annotateMode = !_annotateMode;
                        _moveMode = false;
                        _deleteMode = false;
                        _selectedPinToMove = null;
                        _showMenu = false;
                      });
                    },
                    color: _annotateMode ? Colors.orange : null,
                  ),
                  const SizedBox(height: 8),
                  _buildMenuButton(
                    Icons.open_in_full,
                    'Move',
                    () {
                      setState(() {
                        _moveMode = !_moveMode;
                        _annotateMode = false;
                        _deleteMode = false;
                        _selectedPinToMove = null;
                        _showMenu = false;
                      });
                    },
                    color: _moveMode ? Colors.blue : null,
                  ),
                  const SizedBox(height: 8),
                  _buildMenuButton(
                    Icons.delete_outline,
                    'Delete',
                    () {
                      setState(() {
                        _deleteMode = !_deleteMode;
                        _moveMode = false;
                        _annotateMode = false;
                        _showMenu = false;
                      });
                    },
                    color: _deleteMode ? Colors.red : null,
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _showMenu = !_showMenu;
                      if (!_showMenu) {
                        _annotateMode = false;
                        _moveMode = false;
                        _deleteMode = false;
                        _selectedPinToMove = null;
                      }
                    });
                  },
                  backgroundColor: Colors.blue,
                  child: AnimatedRotation(
                    turns: _showMenu ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(_showMenu ? Icons.close : Icons.menu),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildImageWithPins(int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: GestureDetector(
            onTapDown: (details) {
              if (_annotateMode || (_moveMode && _selectedPinToMove != null)) {
                // Get the tap position relative to the image
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                
                // Normalize to 0-1 range
                final x = localPosition.dx / constraints.maxWidth;
                final y = localPosition.dy / constraints.maxHeight;
                
                // Clamp to valid range
                final clampedX = x.clamp(0.0, 1.0);
                final clampedY = y.clamp(0.0, 1.0);
                
                _handleTapOnPlanFixed(clampedX, clampedY);
              }
            },
            child: Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image - Full Screen
                  Image.file(
                    File(widget.planImages[index].imagePath),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 100,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                  // Pins overlay (inside InteractiveViewer so they move with image)
                  if (index == _currentIndex)
                    ..._pins.map((pin) {
                      // Building-specific numbering: find this pin's index in all building pins
                      final pinIndex = _allBuildingPins.indexWhere((p) => p.id == pin.id) + 1;
                      return Positioned(
                        left: pin.x * constraints.maxWidth - 15,
                        top: pin.y * constraints.maxHeight - 30,
                        child: _moveMode
                            ? Draggable<Pin>(
                                data: pin,
                                feedback: Opacity(
                                  opacity: 0.7,
                                  child: _buildPinWidget(pin, constraints, pinIndex),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildPinWidget(pin, constraints, pinIndex),
                                ),
                                onDragEnd: (details) async {
                                // Convert global position to local
                                final RenderBox box = context.findRenderObject() as RenderBox;
                                final localPosition = box.globalToLocal(details.offset);
                                
                                // Normalize coordinates
                                final x = (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                final y = (localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
                                
                                // Update pin position
                                final updatedPin = Pin(
                                  id: pin.id,
                                  planImageId: pin.planImageId,
                                  x: x,
                                  y: y,
                                  title: pin.title,
                                  description: pin.description,
                                  assignedTo: pin.assignedTo,
                                  status: pin.status,
                                  createdAt: pin.createdAt,
                                );
                                
                                  await DatabaseService.instance.update('pins', updatedPin.toMap(), pin.id!);
                                  _loadPins();
                                },
                                child: _buildPinWidget(pin, constraints, pinIndex),
                              )
                            : GestureDetector(
                                onTap: () => _onPinTap(pin, pinIndex),
                                child: _buildPinWidget(pin, constraints, pinIndex),
                              ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTapOnPlanFixed(double x, double y) async {
    if (_annotateMode) {
      // Add new pin
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinDetailScreen(
            planImage: widget.planImages[_currentIndex],
            x: x,
            y: y,
            pinNumber: _allBuildingPins.length + 1, // Next number for this building
          ),
        ),
      );

      if (result == true) {
        _loadPinsForBuilding(); // Reload building pins first
        _loadPins();
        setState(() {
          _annotateMode = false;
        });
      }
    } else if (_moveMode && _selectedPinToMove != null) {
      // Move selected pin
      final updatedPin = Pin(
        id: _selectedPinToMove!.id,
        planImageId: _selectedPinToMove!.planImageId,
        x: x,
        y: y,
        title: _selectedPinToMove!.title,
        description: _selectedPinToMove!.description,
        assignedTo: _selectedPinToMove!.assignedTo,
        status: _selectedPinToMove!.status,
        createdAt: _selectedPinToMove!.createdAt,
      );
      
      await DatabaseService.instance.update('pins', updatedPin.toMap(), _selectedPinToMove!.id!);
      
      setState(() {
        _selectedPinToMove = null;
        _moveMode = false;
      });
      
      _loadPins();
    }
  }

  Widget _buildPinWidget(Pin pin, BoxConstraints constraints, int pinNumber) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _selectedPinToMove?.id == pin.id 
            ? Colors.blue 
            : pin.getStatusColor(),
        shape: BoxShape.circle,
        border: _selectedPinToMove?.id == pin.id
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$pinNumber',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color ?? Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
