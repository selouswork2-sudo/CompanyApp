class PinComment {
  final int? id;
  final int pinId;
  final String type; // 'comment' or 'photo'
  final String? text; // For comment
  final String? imagePath; // For photo/video
  final DateTime createdAt;

  PinComment({
    this.id,
    required this.pinId,
    required this.type,
    this.text,
    this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pin_id': pinId,
      'type': type,
      'text': text,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PinComment.fromMap(Map<String, dynamic> map) {
    return PinComment(
      id: map['id'] as int?,
      pinId: map['pin_id'] as int,
      type: map['type'] as String,
      text: map['text'] as String?,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}


