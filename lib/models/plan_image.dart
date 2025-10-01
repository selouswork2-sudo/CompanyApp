class PlanImage {
  final int? id;
  final int planId;
  final String imagePath;
  final String name;
  final DateTime createdAt;

  PlanImage({
    this.id,
    required this.planId,
    required this.imagePath,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'image_path': imagePath,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PlanImage.fromMap(Map<String, dynamic> map) {
    return PlanImage(
      id: map['id'] as int?,
      planId: map['plan_id'] as int,
      imagePath: map['image_path'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

