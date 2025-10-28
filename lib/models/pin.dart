import 'package:flutter/material.dart';

class Pin {
  final int? id;
  final int planImageId;
  final double x; // Normalized position 0-1
  final double y; // Normalized position 0-1
  final String title;
  final String? description;
  final String? assignedTo;
  final String status; // Priority 1, Priority 2, Priority 3, Completed, Verified
  final DateTime createdAt;
  // Photo URLs (for Baserow sync)
  final String? beforePicturesUrls;
  final String? duringPicturesUrls;
  final String? afterPicturesUrls;
  // Local photo paths (for fast thumbnail display)
  final String? beforePicturesLocal;
  final String? duringPicturesLocal;
  final String? afterPicturesLocal;
  // Sync metadata
  final int? baserowId;
  final String? syncStatus;
  final String? lastSync;
  final int? needsSync;

  Pin({
    this.id,
    required this.planImageId,
    required this.x,
    required this.y,
    required this.title,
    this.description,
    this.assignedTo,
    this.status = 'Priority 2', // Default orange
    required this.createdAt,
    this.beforePicturesUrls,
    this.duringPicturesUrls,
    this.afterPicturesUrls,
    this.beforePicturesLocal,
    this.duringPicturesLocal,
    this.afterPicturesLocal,
    this.baserowId,
    this.syncStatus,
    this.lastSync,
    this.needsSync,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_image_id': planImageId,
      'x': x,
      'y': y,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'before_pictures_urls': beforePicturesUrls,
      'during_pictures_urls': duringPicturesUrls,
      'after_pictures_urls': afterPicturesUrls,
      'before_pictures_local': beforePicturesLocal,
      'during_pictures_local': duringPicturesLocal,
      'after_pictures_local': afterPicturesLocal,
      'baserow_id': baserowId,
      'sync_status': syncStatus,
      'last_sync': lastSync,
      'needs_sync': needsSync,
    };
  }

  factory Pin.fromMap(Map<String, dynamic> map) {
    return Pin(
      id: map['id'] as int?,
      planImageId: map['plan_image_id'] as int,
      x: map['x'] as double,
      y: map['y'] as double,
      title: map['title'] as String,
      description: map['description'] as String?,
      assignedTo: map['assigned_to'] as String?,
      status: map['status'] as String? ?? 'Priority 2',
      createdAt: DateTime.parse(map['created_at'] as String),
      beforePicturesUrls: map['before_pictures_urls'] as String?,
      duringPicturesUrls: map['during_pictures_urls'] as String?,
      afterPicturesUrls: map['after_pictures_urls'] as String?,
      beforePicturesLocal: map['before_pictures_local'] as String?,
      duringPicturesLocal: map['during_pictures_local'] as String?,
      afterPicturesLocal: map['after_pictures_local'] as String?,
      baserowId: map['baserow_id'] as int?,
      syncStatus: map['sync_status'] as String?,
      lastSync: map['last_sync'] as String?,
      needsSync: map['needs_sync'] as int?,
    );
  }

  Color getStatusColor() {
    switch (status) {
      case 'Priority 1':
        return const Color(0xFFE53935); // Red
      case 'Priority 2':
        return const Color(0xFFFF9800); // Orange
      case 'Priority 3':
        return const Color(0xFFFFC107); // Yellow
      case 'Completed':
        return const Color(0xFF4CAF50); // Green
      case 'Verified':
        return const Color(0xFF03A9F4); // Light Blue
      default:
        return const Color(0xFFFF9800); // Orange default
    }
  }
}
