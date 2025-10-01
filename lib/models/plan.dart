class Plan {
  final int? id;
  final int projectId;
  final String jobNumber; // Format: JXXXX.X.X
  final String? name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plan({
    this.id,
    required this.projectId,
    required this.jobNumber,
    this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'job_number': jobNumber,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    );
  }

  // Validate Job Number format: JXXXX.X.X
  static bool isValidJobNumber(String jobNumber) {
    final regex = RegExp(r'^J\d{4}\.\d+\.\d+$');
    return regex.hasMatch(jobNumber);
  }
}

