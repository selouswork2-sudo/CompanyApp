import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../services/baserow_service.dart';
import '../services/sync_service.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_project_dialog.dart';
import '../widgets/status_chips_widget.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  List<Project> _filteredProjects = [];
  bool _isLoading = true;
  bool _isOnline = true;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadProjects();
    _searchController.addListener(_filterProjects);
    _startAutoSync();
  }

  void _startAutoSync() {
    // Auto-sync every 30 seconds when online
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isOnline) {
        _performBackgroundSync();
        _startAutoSync(); // Schedule next sync
      }
    });
  }

  Future<void> _performBackgroundSync() async {
    try {
      final syncResult = await SyncService.performFullSync();
      if (syncResult.success && syncResult.projectsSynced > 0) {
        // Reload projects if new data was synced
        await _reloadProjectsAfterSync();
        print('🔄 Background sync completed: ${syncResult.projectsSynced} projects');
      }
    } catch (e) {
      print('⚠️ Background sync failed: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = connectivityResult != ConnectivityResult.none;
      });
    }
    
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOnline = results.first != ConnectivityResult.none;
        });
        
        // Auto-sync when connection is restored
        if (_isOnline) {
          _syncWithBaserow();
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    
    try {
      if (_isOnline) {
        // Online: Perform full bidirectional sync
        final syncResult = await SyncService.performFullSync();
        print('🔄 Sync result: ${syncResult.message}');
      }
      
      // Always load from local database (offline-first)
      final maps = await DatabaseService.instance.query('projects');
      final projects = maps.map((m) => Project.fromMap(m)).toList();
      
      setState(() {
        _projects = projects;
        _filteredProjects = projects;
        _isLoading = false;
      });
      
      print('✅ Loaded ${projects.length} projects from local database');
      
    } catch (e) {
      print('❌ Failed to load projects: $e');
      setState(() {
        _projects = [];
        _filteredProjects = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWithBaserow() async {
    if (!_isOnline) return;
    
    try {
      final syncResult = await SyncService.performFullSync();
      
      if (syncResult.success) {
        await _reloadProjectsAfterSync();
      }
    } catch (e) {
      print('❌ Sync failed: $e');
      // swallow
    }
  }

  Future<void> _reloadProjectsAfterSync() async {
    try {
      // Load from local database without showing loading indicator
      final maps = await DatabaseService.instance.query('projects');
      final projects = maps.map((m) => Project.fromMap(m)).toList();
      
      setState(() {
        _projects = projects;
        _filteredProjects = projects;
      });
      
      print('✅ Reloaded ${projects.length} projects after sync');
      
    } catch (e) {
      print('❌ Failed to reload projects: $e');
    }
  }
  

  void _filterProjects() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProjects = _projects;
      } else {
        _filteredProjects = _projects.where((project) {
          return project.name.toLowerCase().contains(query) ||
              (project.address?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateProjectDialog(),
    );

    if (result != null) {
      try {
        final now = DateTime.now().toIso8601String();
        final project = Project(
          name: result['name']!,
          address: result['address'] ?? '',
          status: result['status'] ?? 'Active',
          startDate: now,
          createdAt: now,
          updatedAt: now,
        );
        
        // Use SyncService to create project locally and queue for sync
        await SyncService.createProjectLocally(project);
        
        // Trigger background sync immediately
        SyncService.performFullSync().then((_) {
          print('✅ Background sync completed after project creation');
        }).catchError((error) {
          print('⚠️ Background sync failed: $error');
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${result['name']}" created successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
          _reloadProjectsAfterSync();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating project: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _editProject(Project project) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditProjectDialog(
        currentName: project.name,
        currentAddress: project.address ?? '',
        currentStatus: project.status,
      ),
    );

    if (result != null) {
      try {
        final updatedProject = Project(
          id: project.id,
          name: result['name']!,
          address: result['address'] ?? '',
          status: result['status'] ?? 'Active',
          startDate: project.startDate,
          endDate: project.endDate,
          createdAt: project.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
          // Preserve sync metadata
          baserowId: project.baserowId,
          syncStatus: project.syncStatus,
          lastSync: project.lastSync,
          needsSync: project.needsSync,
        );
        
        // Use SyncService to update project locally and queue for sync
        await SyncService.updateProjectLocally(updatedProject);
        
        // Trigger background sync immediately
        SyncService.performFullSync().then((_) {
          print('✅ Background sync completed after project update');
        }).catchError((error) {
          print('⚠️ Background sync failed: $error');
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${result['name']}" updated successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
          _reloadProjectsAfterSync();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating project: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile - Coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Logout functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged out')),
                          );
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Go back to home screen instead of closing app
        context.go('/');
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Projects'),
              const SizedBox(width: 8),
              Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: _isOnline ? Colors.green : Colors.red,
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [],
        ),
        body: SafeArea(
        child: Column(
          children: [
            // Modern Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Search Field
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search projects...',
                          hintStyle: TextStyle(color: AppTheme.textLight),
                          prefixIcon: Icon(Icons.search, color: AppTheme.textLight),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white, size: 24),
                      onPressed: _createProject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Menu Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_vert, color: AppTheme.textPrimary, size: 24),
                      onPressed: _showMenu,
                    ),
                  ),
                ],
              ),
            ),
            // Projects List Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Projects',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_filteredProjects.length}',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Projects List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProjects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? (_isOnline ? 'No projects yet' : 'Working offline')
                                    : 'No matching projects',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isEmpty
                                    ? (_isOnline 
                                        ? 'Tap + to create your first project'
                                        : 'Data will sync when connection is restored')
                                    : 'Try a different search',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _syncWithBaserow,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredProjects.length,
                            itemBuilder: (context, index) {
                              final project = _filteredProjects[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildSimpleProjectCard(project),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSimpleProjectCard(Project project) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: () => _showProjectContextMenu(project),
        child: InkWell(
          onTap: () => context.go('/building/${project.id}'),
          borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Left side - Project info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Name
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        
                        // Address
                        if (project.address != null && project.address!.isNotEmpty)
                          Text(
                            project.address!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Right side - Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(project.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      project.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  void _showProjectContextMenu(Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Project'),
              onTap: () {
                Navigator.pop(context);
                _editProject(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Project'),
              onTap: () {
                Navigator.pop(context);
                _deleteProject(project);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete project and cascade delete all related jobs and plans
        await SyncService.deleteProjectLocally(project.id!);
        
        // Trigger background sync immediately
        SyncService.performFullSync().then((_) {
          print('✅ Background sync completed after project deletion');
        }).catchError((error) {
          print('⚠️ Background sync failed: $error');
        });
        
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${project.name}" deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting project: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'planning':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class ProjectListTile extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ProjectListTile({
    super.key,
    required this.project,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  void _showProjectMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Edit', style: TextStyle(color: Colors.blue, fontSize: 16)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService.instance.delete('projects', project.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${project.name} deleted')),
                );
                // Refresh the list immediately
                onDelete();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showProjectMenu(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Building Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            // Project Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (project.address != null &&
                      project.address!.isNotEmpty) ...[
                    Text(
                      project.address!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  StatusChipsWidget(
                    status: project.status,
                    isCompact: true,
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right, color: AppTheme.textLight, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedStatus = 'Active';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'New Project',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Building Name *',
                hintText: 'Enter building name',
                prefixIcon: const Icon(Icons.business, color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Building Address',
                hintText: 'Enter building address',
                prefixIcon: const Icon(Icons.location_on, color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status *',
                prefixIcon: const Icon(Icons.info, color: AppTheme.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
              items: ['Active', 'Completed', 'On Hold', 'Cancelled']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'Active';
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'address': _addressController.text,
                  'status': _selectedStatus,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create Project',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
