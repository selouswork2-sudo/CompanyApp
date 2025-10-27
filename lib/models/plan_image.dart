class PlanImage {
  final int? id;
  final int jobId;
  final String imagePath;
  final String name;
  final DateTime createdAt;
  final int? baserowId;
  final String? syncStatus;
  final String? lastSync;
  final int? needsSync;

  PlanImage({
    this.id,
    required this.jobId,
    required this.imagePath,
    required this.name,
    required this.createdAt,
    this.baserowId,
    this.syncStatus,
    this.lastSync,
    this.needsSync,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_id': jobId,
      'image_path': imagePath,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'baserow_id': baserowId,
      'sync_status': syncStatus,
      'last_sync': lastSync,
      'needs_sync': needsSync,
    };
  }

  factory PlanImage.fromMap(Map<String, dynamic> map) {
    return PlanImage(
      id: map['id'] is int ? map['id'] as int? : int.tryParse(map['id']?.toString() ?? ''),
      jobId: map['job_id'] is int ? map['job_id'] as int : int.parse(map['job_id']?.toString() ?? '0'),
      imagePath: map['image_path']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: DateTime.parse(map['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      baserowId: map['baserow_id'] is int ? map['baserow_id'] as int? : int.tryParse(map['baserow_id']?.toString() ?? ''),
      syncStatus: map['sync_status']?.toString(),
      lastSync: map['last_sync']?.toString(),
      needsSync: map['needs_sync'] is int ? map['needs_sync'] as int? : int.tryParse(map['needs_sync']?.toString() ?? ''),
    );
  }
}

