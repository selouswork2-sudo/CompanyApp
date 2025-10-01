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
