class Plan {
  final int? id;
  final int projectId;
  final String jobNumber; // Format: JXXXX.X.X
  final String? name;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Sync metadata
  final int? baserowId;
  final String? syncStatus;
  final String? lastSync;
  final int? needsSync;

  Plan({
    this.id,
    required this.projectId,
    required this.jobNumber,
    this.name,
    required this.createdAt,
    required this.updatedAt,
    this.baserowId,
    this.syncStatus,
    this.lastSync,
    this.needsSync,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'job_number': jobNumber,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'baserow_id': baserowId,
      'sync_status': syncStatus,
      'last_sync': lastSync,
      'needs_sync': needsSync,
    };
  }

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      jobNumber: map['job_number'] as String,
      name: map['name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      baserowId: map['baserow_id'] as int?,
      syncStatus: map['sync_status'] as String?,
      lastSync: map['last_sync'] as String?,
      needsSync: map['needs_sync'] as int?,
    );
  }

  // Validate Job Number format: JXXXX.X.X
  static bool isValidJobNumber(String jobNumber) {
    final regex = RegExp(r'^J\d{4}\.\d+\.\d+$');
    return regex.hasMatch(jobNumber);
  }
}

