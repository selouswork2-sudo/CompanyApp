enum JobStatus {
  pending,    // Beklemede
  approved,   // Onaylandı
  inProgress, // Yapılıyor
  completed,  // Yapıldı
  rejected,   // Reddedildi
}

class Job {
  final int? id;
  final int projectId;
  final String jobNumber;
  final String name;
  final JobStatus status;
  final String? description;
  final String? assignedTo;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? baserowId;
  final String syncStatus;
  final DateTime? lastSync;
  final int needsSync;

  Job({
    this.id,
    required this.projectId,
    required this.jobNumber,
    required this.name,
    this.status = JobStatus.pending,
    this.description,
    this.assignedTo,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.baserowId,
    this.syncStatus = 'synced',
    this.lastSync,
    this.needsSync = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'job_number': jobNumber,
      'name': name,
      'status': status.name,
      'description': description,
      'assigned_to': assignedTo,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'baserow_id': baserowId,
      'sync_status': syncStatus,
      'last_sync': lastSync?.toIso8601String(),
      'needs_sync': needsSync,
    };
  }

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      jobNumber: map['job_number'] as String,
      name: map['name'] as String,
      status: JobStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JobStatus.pending,
      ),
      description: map['description'] as String?,
      assignedTo: map['assigned_to'] as String?,
      dueDate: map['due_date'] != null 
          ? DateTime.parse(map['due_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      baserowId: map['baserow_id'] as int?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      lastSync: map['last_sync'] != null 
          ? DateTime.parse(map['last_sync'] as String)
          : null,
      needsSync: map['needs_sync'] as int? ?? 0,
    );
  }

  Job copyWith({
    int? id,
    int? projectId,
    String? jobNumber,
    String? name,
    JobStatus? status,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? baserowId,
    String? syncStatus,
    DateTime? lastSync,
    int? needsSync,
  }) {
    return Job(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      jobNumber: jobNumber ?? this.jobNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      baserowId: baserowId ?? this.baserowId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSync: lastSync ?? this.lastSync,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  // Status display helpers
  String get statusDisplayName {
    switch (status) {
      case JobStatus.pending:
        return 'Beklemede';
      case JobStatus.approved:
        return 'Onaylandı';
      case JobStatus.inProgress:
        return 'Yapılıyor';
      case JobStatus.completed:
        return 'Yapıldı';
      case JobStatus.rejected:
        return 'Reddedildi';
    }
  }

  // Status color helpers
  String get statusColor {
    switch (status) {
      case JobStatus.pending:
        return 'orange';
      case JobStatus.approved:
        return 'blue';
      case JobStatus.inProgress:
        return 'yellow';
      case JobStatus.completed:
        return 'green';
      case JobStatus.rejected:
        return 'red';
    }
  }
}

