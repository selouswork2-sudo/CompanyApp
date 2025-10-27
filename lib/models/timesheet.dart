class Timesheet {
  final int? id;
  final int projectId;
  final int? planId; // Job ID
  final String userId; // Who worked
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String? notes;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;

  Timesheet({
    this.id,
    required this.projectId,
    this.planId,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculate total hours worked
  double get totalHours {
    final duration = endTime.difference(startTime);
    return duration.inMinutes / 60.0;
  }

  // Format total hours as string
  String get totalHoursFormatted {
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'plan_id': planId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Timesheet.fromMap(Map<String, dynamic> map) {
    return Timesheet(
      id: map['id'],
      projectId: map['project_id'],
      planId: map['plan_id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      notes: map['notes'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Timesheet copyWith({
    int? id,
    int? projectId,
    int? planId,
    String? userId,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Timesheet(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      planId: planId ?? this.planId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

