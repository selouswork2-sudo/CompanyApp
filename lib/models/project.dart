class Project {
  final int? id;
  final String name;
  final String? address;
  final String status;
  final String? startDate;
  final String? endDate;
  final String? description;
  final String createdAt;
  final String updatedAt;

  Project({
    this.id,
    required this.name,
    this.address,
    this.status = 'Active',
    this.startDate,
    this.endDate,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      status: map['status'] ?? 'Active',
      startDate: map['start_date'],
      endDate: map['end_date'],
      description: map['description'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

