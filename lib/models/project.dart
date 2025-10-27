class Project {
  final int? id;
  final String name;
  final String? address;
  final String status; // Changed back to String for single select
  final String? startDate;
  final String? endDate;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  
  // Sync metadata
  final int? baserowId;
  final String? syncStatus;
  final String? lastSync;
  final int? needsSync;

  Project({
    this.id,
    required this.name,
    this.address,
    this.status = 'Active', // Default to Active
    this.startDate,
    this.endDate,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.baserowId,
    this.syncStatus,
    this.lastSync,
    this.needsSync,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'status': status, // Single select - just string
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'baserow_id': baserowId,
      'sync_status': syncStatus,
      'last_sync': lastSync,
      'needs_sync': needsSync,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    // Handle both Baserow format (single object) and local format (string)
    String statusString = 'Active';
    if (map['status'] is List) {
      // Baserow format: [{"id": 3055, "value": "Active", "color": "green"}]
      final statusList = map['status'] as List;
      if (statusList.isNotEmpty && statusList.first is Map<String, dynamic>) {
        statusString = statusList.first['value'] ?? 'Active';
      }
    } else if (map['status'] is String) {
      // Local format: "Active"
      statusString = map['status'];
    }
    
    // Parse date fields
    String? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is String) return dateValue;
      if (dateValue is DateTime) return dateValue.toIso8601String();
      return dateValue.toString();
    }
    
    
    return Project(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      status: statusString,
      startDate: parseDate(map['start_date']),
      endDate: parseDate(map['end_date']),
      description: map['description'],
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      baserowId: map['baserow_id'],
      syncStatus: map['sync_status'],
      lastSync: map['last_sync'],
      needsSync: map['needs_sync'],
    );
  }
}

