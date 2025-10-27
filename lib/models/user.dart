enum UserRole {
  manager,
  supervisor,
  technician,
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: UserRole.values.firstWhere((e) => e.name == map['role']),
    );
  }

  // Permission checks
  bool canCreateProject() => true; // All users can create projects
  bool canEditProject() => true; // All users can edit projects
  bool canDeleteProject() => role == UserRole.manager; // Only managers can delete
  
  bool canCreateJob() => true; // All users can create jobs
  bool canEditJob() => true; // All users can edit jobs
  bool canDeleteJob() => role == UserRole.manager; // Only managers can delete
  
  bool canChangeJobStatus() => role == UserRole.manager || role == UserRole.supervisor;
  bool canViewAllProjects() => true; // All users can view all projects
}