import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pin.dart';
import '../models/plan_image.dart';
import '../models/pin_comment.dart';
import '../services/database_service.dart';
import 'plan_viewer_screen.dart';

class PinDetailScreen extends StatefulWidget {
  final Pin? pin;
  final PlanImage planImage;
  final double x;
  final double y;
  final int? pinNumber; // Building-specific pin number

  const PinDetailScreen({
    super.key,
    this.pin,
    required this.planImage,
    required this.x,
    required this.y,
    this.pinNumber,
  });

  @override
  State<PinDetailScreen> createState() => _PinDetailScreenState();
}

class _PinDetailScreenState extends State<PinDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _commentController;
  bool _isSaving = false;
  String _selectedStatus = 'Priority 2';
  List<PinComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.pin?.title ?? 'Enter Title');
    _descriptionController = TextEditingController(text: widget.pin?.description ?? '');
    _commentController = TextEditingController();
    _selectedStatus = widget.pin?.status ?? 'Priority 2';
    
    // Select all text when opening
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
    
    if (widget.pin != null) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    final maps = await DatabaseService.instance.query(
      'pin_comments',
      where: 'pin_id = ?',
      whereArgs: [widget.pin!.id],
    );
    setState(() {
      _comments = maps.map((e) => PinComment.fromMap(e)).toList();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_titleController.text.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final pin = Pin(
      id: widget.pin?.id,
      planImageId: widget.planImage.id!,
      x: widget.x,
      y: widget.y,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      status: _selectedStatus,
      createdAt: widget.pin?.createdAt ?? DateTime.now(),
    );

    if (widget.pin == null) {
      await DatabaseService.instance.insert('pins', pin.toMap());
    } else {
      await DatabaseService.instance.update('pins', pin.toMap(), widget.pin!.id!);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _addComment() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Add Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _commentController,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: 'Enter your comment',
            hintStyle: TextStyle(color: Colors.black38),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_commentController.text.isEmpty || widget.pin == null) return;
              
              final comment = PinComment(
                pinId: widget.pin!.id!,
                type: 'comment',
                text: _commentController.text,
                createdAt: DateTime.now(),
              );
              
              await DatabaseService.instance.insert('pin_comments', comment.toMap());
              _commentController.clear();
              Navigator.pop(context);
              _loadComments();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (widget.pin == null) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
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

    final comment = PinComment(
      pinId: widget.pin!.id!,
      type: 'photo',
      imagePath: image.path,
      createdAt: DateTime.now(),
    );

    await DatabaseService.instance.insert('pin_comments', comment.toMap());
    _loadComments();
  }

  Widget _buildCommentItem(PinComment comment) {
    if (comment.type == 'comment') {
      return InkWell(
        onLongPress: () => _deleteComment(comment),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.text ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(comment.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onLongPress: () => _deleteComment(comment),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(comment.imagePath!),
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  void _deleteComment(PinComment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(
          'Delete ${comment.type == 'comment' ? 'Comment' : 'Photo'}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this ${comment.type}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService.instance.delete('pin_comments', comment.id!);
              _loadComments();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Save and go back instead of closing app
        await _savePin();
        return false; // Prevent default back action
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        leading: TextButton(
          onPressed: () async {
            await _savePin();
          },
          child: const Text(
            'Done',
            style: TextStyle(color: Colors.blue, fontSize: 16),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          widget.pin == null ? 'New Task' : 'Task #${widget.pinNumber ?? widget.pin!.id}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _showStatusDialog,
            child: const Text(
              'Edit',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pin icon and title (Fixed at top)
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2C2C2E),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Pin(
                      planImageId: 0,
                      x: 0,
                      y: 0,
                      title: '',
                      status: _selectedStatus,
                      createdAt: DateTime.now(),
                    ).getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${widget.pinNumber ?? widget.pin?.id ?? 'New'} | @${widget.planImage.name}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      TextField(
                        controller: _titleController,
                        autofocus: false,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: 'Enter Title',
                          hintStyle: TextStyle(color: Colors.black38),
                        ),
                        onTap: () {
                          // Select all when tapped
                          _titleController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _titleController.text.length,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content (plan + comments)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Plan thumbnail with pin location
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1C1C1E),
                    child: Column(
                      children: [
                        Text(
                          widget.planImage.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            // Open full screen plan viewer
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlanViewerScreen(
                                  planImages: [widget.planImage],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(widget.planImage.imagePath),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Show pin location on thumbnail
                              if (widget.pin != null)
                                Positioned(
                                  left: widget.x * MediaQuery.of(context).size.width * 0.85 - 12,
                                  top: widget.y * 200 - 12,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Pin(
                                        planImageId: 0,
                                        x: 0,
                                        y: 0,
                                        title: '',
                                        status: _selectedStatus,
                                        createdAt: DateTime.now(),
                                      ).getStatusColor(),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black87,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${widget.pinNumber ?? widget.pin!.id}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comments and Photos
                  Container(
                    color: const Color(0xFF1C1C1E),
                    padding: const EdgeInsets.all(16),
                    child: _comments.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Text(
                                'No comments or photos yet',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          )
                        : Column(
                            children: _comments.map((comment) => _buildCommentItem(comment)).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.chat_bubble_outline, 'Comment', _addComment),
                  _buildActionButton(Icons.camera_alt_outlined, 'Photo', _addPhoto),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Status', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('Priority 1', const Color(0xFFE53935)),
            _buildStatusOption('Priority 2', const Color(0xFFFF9800)),
            _buildStatusOption('Priority 3', const Color(0xFFFFC107)),
            _buildStatusOption('Completed', const Color(0xFF4CAF50)),
            _buildStatusOption('Verified', const Color(0xFF03A9F4)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.blue, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.blue,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}