import 'package:flutter/material.dart';
import '../models/timesheet.dart';
import '../models/project.dart';
import '../models/plan.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> with TickerProviderStateMixin {
  List<Project> _projects = [];
  List<Plan> _plans = [];
  List<Timesheet> _timesheets = [];
  Project? _selectedProject;
  Plan? _selectedPlan;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingProjects = true;
  bool _isLoadingTimesheets = true;
  late TabController _tabController;
  Map<int, Project> _projectsMap = {};
  Map<int, Plan> _plansMap = {};
  Timesheet? _editingTimesheet;
  DateTime _overviewStartDate = DateTime.now().subtract(const Duration(days: 14)); // Overview date range

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProjects();
    _loadTimesheets();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final maps = await DatabaseService.instance.query('projects');
      setState(() {
        _projects = maps.map((e) => Project.fromMap(e)).toList();
        _projectsMap = {for (var p in _projects) p.id!: p};
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadTimesheets() async {
    setState(() {
      _isLoadingTimesheets = true;
    });

    try {
      final timesheetMaps = await DatabaseService.instance.query('timesheets');
      final loadedTimesheets = timesheetMaps.map((e) => Timesheet.fromMap(e)).toList();
      
      // Sort by date descending
      loadedTimesheets.sort((a, b) => b.date.compareTo(a.date));

      // Load related plans
      final planMaps = await DatabaseService.instance.query('plans');
      _plansMap = {for (var p in planMaps) p['id'] as int: Plan.fromMap(p)};

      setState(() {
        _timesheets = loadedTimesheets;
        _isLoadingTimesheets = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTimesheets = false;
      });
    }
  }

  Future<void> _loadPlansForProject(int projectId) async {
    try {
      final maps = await DatabaseService.instance.query(
        'plans',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      setState(() {
        _plans = maps.map((e) => Plan.fromMap(e)).toList();
      });
    } catch (e) {
      setState(() {
        _plans = [];
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if it's before start time
        if (_endTime.hour < _startTime.hour || 
            (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
          _endTime = TimeOfDay(
            hour: (_startTime.hour + 1) % 24,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  double _calculateTotalHours() {
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    
    if (endDateTime.isBefore(startDateTime)) {
      return 0.0;
    }
    
    final duration = endDateTime.difference(startDateTime);
    return duration.inMinutes / 60.0;
  }

  String _formatTotalHours(double hours) {
    final hoursInt = hours.floor();
    final minutes = ((hours - hoursInt) * 60).round();
    if (minutes == 0) {
      return '${hoursInt}h';
    } else {
      return '${hoursInt}h ${minutes}m';
    }
  }

  Future<void> _saveTimesheet() async {
    if (_selectedProject == null) {
      _showErrorDialog('Please select a project');
      return;
    }

    if (_endTime.hour < _startTime.hour || 
        (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
      _showErrorDialog('End time must be after start time');
      return;
    }

    // Check for time conflicts
    final conflict = await _checkTimeConflicts();
    if (conflict != null) {
      _showErrorDialog(conflict);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final timesheet = Timesheet(
        projectId: _selectedProject!.id!,
        planId: _selectedPlan?.id,
        userId: 'current_user', // TODO: Get from auth
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DatabaseService.instance.insert('timesheets', timesheet.toMap());

      if (mounted) {
        _showSuccessDialog();
        _resetForm();
        _loadTimesheets(); // Refresh the timesheet list
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to save timesheet: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _checkTimeConflicts() async {
    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Get all timesheets for the same date
      final timesheetMaps = await DatabaseService.instance.query('timesheets');
      
      // Filter by date manually since date is stored as DateTime
      final filteredTimesheets = timesheetMaps.where((map) {
        final timesheetDate = DateTime.parse(map['date']);
        return timesheetDate.year == _selectedDate.year &&
               timesheetDate.month == _selectedDate.month &&
               timesheetDate.day == _selectedDate.day;
      }).toList();

      for (var map in filteredTimesheets) {
        final existingTimesheet = Timesheet.fromMap(map);
        
        // Check if times overlap
        if (_timesOverlap(
          startDateTime, endDateTime,
          existingTimesheet.startTime, existingTimesheet.endTime,
        )) {
          final project = _projectsMap[existingTimesheet.projectId];
          final plan = existingTimesheet.planId != null ? _plansMap[existingTimesheet.planId!] : null;
          final projectName = project?.name ?? 'Unknown Project';
          final jobName = plan?.jobNumber ?? '';
          
          return 'Time conflict detected!\n\nYou already have a timesheet entry for:\n• Project: $projectName\n• Job: $jobName\n• Time: ${_formatDateTime(existingTimesheet.startTime)} - ${_formatDateTime(existingTimesheet.endTime)}\n\nPlease choose different hours or edit the existing entry.';
        }
      }

      return null; // No conflicts
    } catch (e) {
      return 'Error checking time conflicts: $e';
    }
  }

  bool _timesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    // Check if two time ranges overlap
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  void _resetForm() {
    setState(() {
      _selectedProject = null;
      _selectedPlan = null;
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.now();
      _notesController.clear();
      _plans = [];
      _editingTimesheet = null;
    });
  }

  void _editTimesheet(Timesheet timesheet) {
    setState(() {
      _editingTimesheet = timesheet;
      _selectedProject = _projectsMap[timesheet.projectId];
      _selectedPlan = timesheet.planId != null ? _plansMap[timesheet.planId!] : null;
      _selectedDate = timesheet.date;
      _startTime = TimeOfDay.fromDateTime(timesheet.startTime);
      _endTime = TimeOfDay.fromDateTime(timesheet.endTime);
      _notesController.text = timesheet.notes ?? '';
      
      // Load plans for the selected project
      if (_selectedProject != null) {
        _loadPlansForProject(_selectedProject!.id!);
      }
    });
    
    // Switch to New Entry tab
    _tabController.animateTo(0);
  }

  Future<void> _updateTimesheet() async {
    if (_selectedProject == null) {
      _showErrorDialog('Please select a project');
      return;
    }

    if (_endTime.hour < _startTime.hour || 
        (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
      _showErrorDialog('End time must be after start time');
      return;
    }

    // Check for time conflicts (excluding the current timesheet being edited)
    final conflict = await _checkTimeConflictsForEdit();
    if (conflict != null) {
      _showErrorDialog(conflict);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final updatedTimesheet = Timesheet(
        id: _editingTimesheet!.id,
        projectId: _selectedProject!.id!,
        planId: _selectedPlan?.id,
        userId: _editingTimesheet!.userId,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        status: _editingTimesheet!.status,
        createdAt: _editingTimesheet!.createdAt,
        updatedAt: DateTime.now(),
      );

      await DatabaseService.instance.update(
        'timesheets',
        updatedTimesheet.toMap(),
        updatedTimesheet.id!,
      );

      if (mounted) {
        _showSuccessDialog('Timesheet updated successfully!');
        _resetForm();
        _loadTimesheets(); // Refresh the timesheet list
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to update timesheet: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _checkTimeConflictsForEdit() async {
    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Get all timesheets for the same date (excluding the one being edited)
      final timesheetMaps = await DatabaseService.instance.query('timesheets');
      
      // Filter by date manually since date is stored as DateTime
      final filteredTimesheets = timesheetMaps.where((map) {
        final timesheetDate = DateTime.parse(map['date']);
        return timesheetDate.year == _selectedDate.year &&
               timesheetDate.month == _selectedDate.month &&
               timesheetDate.day == _selectedDate.day &&
               map['id'] != _editingTimesheet!.id;
      }).toList();

      for (var map in filteredTimesheets) {
        final existingTimesheet = Timesheet.fromMap(map);
        
        // Check if times overlap
        if (_timesOverlap(
          startDateTime, endDateTime,
          existingTimesheet.startTime, existingTimesheet.endTime,
        )) {
          final project = _projectsMap[existingTimesheet.projectId];
          final plan = existingTimesheet.planId != null ? _plansMap[existingTimesheet.planId!] : null;
          final projectName = project?.name ?? 'Unknown Project';
          final jobName = plan?.jobNumber ?? '';
          
          return 'Time conflict detected!\n\nYou already have a timesheet entry for:\n• Project: $projectName\n• Job: $jobName\n• Time: ${_formatDateTime(existingTimesheet.startTime)} - ${_formatDateTime(existingTimesheet.endTime)}\n\nPlease choose different hours.';
        }
      }

      return null; // No conflicts
    } catch (e) {
      return 'Error checking time conflicts: $e';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog([String? message]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message ?? 'Timesheet saved successfully!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Timesheet'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
                 tabs: [
                   Tab(
                     icon: Icon(_editingTimesheet != null ? Icons.edit : Icons.add),
                     text: _editingTimesheet != null ? 'Edit Entry' : 'New Entry',
                   ),
                   const Tab(
                     icon: Icon(Icons.history),
                     text: 'History',
                   ),
                   const Tab(
                     icon: Icon(Icons.analytics),
                     text: 'Overview',
                   ),
                 ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // New Entry Tab
            _buildNewEntryTab(),
            // History Tab
            _buildHistoryTab(),
            // Overview Tab
            _buildOverviewTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewEntryTab() {
    return _isLoadingProjects
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Selection
                      _buildSectionCard(
                        title: 'Project',
                        icon: Icons.business,
                        child: DropdownButtonFormField<Project>(
                          value: _selectedProject,
                          decoration: InputDecoration(
                            hintText: 'Select a project',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.business, size: 18),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _projects.map((project) {
                            return DropdownMenuItem(
                              value: project,
                              child: Text(project.name),
                            );
                          }).toList(),
                          onChanged: (Project? project) {
                            setState(() {
                              _selectedProject = project;
                              _selectedPlan = null;
                              _plans = [];
                            });
                            if (project != null) {
                              _loadPlansForProject(project.id!);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Job Selection
                      _buildSectionCard(
                        title: 'Job (Optional)',
                        icon: Icons.work,
                        child: DropdownButtonFormField<Plan>(
                          value: _selectedPlan,
                          decoration: InputDecoration(
                            hintText: 'Select a job (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.work, size: 18),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _plans.map((plan) {
                            return DropdownMenuItem(
                              value: plan,
                              child: Text(plan.jobNumber),
                            );
                          }).toList(),
                          onChanged: _selectedProject == null
                              ? null
                              : (Plan? plan) {
                                  setState(() {
                                    _selectedPlan = plan;
                                  });
                                },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Date Selection
                      _buildSectionCard(
                        title: 'Date',
                        icon: Icons.calendar_today,
                        child: InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: AppTheme.primaryBlue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Time Selection
                      _buildSectionCard(
                        title: 'Working Hours',
                        icon: Icons.access_time,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTimeSelector(
                                    label: 'Start Time',
                                    time: _startTime,
                                    onTap: _selectStartTime,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTimeSelector(
                                    label: 'End Time',
                                    time: _endTime,
                                    onTap: _selectEndTime,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryBlue.withOpacity(0.1),
                                    AppTheme.primaryBlue.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.timer,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total: ${_formatTotalHours(_calculateTotalHours())}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Notes
                      _buildSectionCard(
                        title: 'Notes (Optional)',
                        icon: Icons.note,
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Add any notes about your work...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.note, size: 18),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              // Save Button - Fixed at bottom
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_editingTimesheet != null ? _updateTimesheet : _saveTimesheet),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              _editingTimesheet != null ? 'Update Timesheet' : 'Save Timesheet',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildHistoryTab() {
    return _isLoadingTimesheets
        ? const Center(child: CircularProgressIndicator())
        : _timesheets.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No timesheet entries yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add new entries from the "New Entry" tab',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _timesheets.length,
                      itemBuilder: (context, index) {
                  final timesheet = _timesheets[index];
                  final project = _projectsMap[timesheet.projectId];
                  final plan = timesheet.planId != null ? _plansMap[timesheet.planId!] : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: InkWell(
                      onTap: () => _editTimesheet(timesheet),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                            Text(
                              _formatDate(timesheet.date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(timesheet.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  timesheet.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(timesheet.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Project: ${project?.name ?? 'N/A'}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          if (plan != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Job: ${plan.jobNumber}',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatDateTime(timesheet.startTime)} - ${_formatDateTime(timesheet.endTime)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatTotalHours(_calculateTotalHoursForTimesheet(timesheet)),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (timesheet.notes != null && timesheet.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Notes: ${timesheet.notes}',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  );
                },
              );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  double _calculateTotalHoursForTimesheet(Timesheet timesheet) {
    final duration = timesheet.endTime.difference(timesheet.startTime);
    return duration.inMinutes / 60.0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return AppTheme.warning;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryBlue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppTheme.primaryBlue, size: 16),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectOverviewStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _overviewStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _overviewStartDate) {
      setState(() {
        _overviewStartDate = picked;
      });
    }
  }

  Widget _buildOverviewTab() {
    // Get timesheets for selected 2-week period
    final endDate = _overviewStartDate.add(const Duration(days: 14));
    final recentTimesheets = _timesheets.where((timesheet) => 
      timesheet.date.isAfter(_overviewStartDate.subtract(const Duration(days: 1))) && 
      timesheet.date.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();

    // Calculate total hours
    double totalHours = 0;
    for (var timesheet in recentTimesheets) {
      totalHours += _calculateTotalHoursForTimesheet(timesheet);
    }

    return Column(
      children: [
        // Date Selection and Total Hours Summary - Always visible
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlue.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Date Selection
              InkWell(
                onTap: _selectOverviewStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_overviewStartDate.day}/${_overviewStartDate.month}/${_overviewStartDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Total Hours
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.timer,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Hours',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTotalHours(totalHours),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table View
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Project',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Job',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Time',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Body
                Expanded(
                  child: recentTimesheets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No timesheet entries in selected period',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add entries to see your overview',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: recentTimesheets.length,
                          itemBuilder: (context, index) {
                            final timesheet = recentTimesheets[index];
                            final project = _projectsMap[timesheet.projectId];
                            final plan = timesheet.planId != null ? _plansMap[timesheet.planId!] : null;
                            final isEven = index % 2 == 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isEven ? Colors.white : Colors.grey[50],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _formatDate(timesheet.date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      project?.name ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      plan?.jobNumber ?? '-',
                                      style: const TextStyle(
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_formatDateTime(timesheet.startTime)}-${_formatDateTime(timesheet.endTime)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      _formatTotalHours(_calculateTotalHoursForTimesheet(timesheet)),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(timesheet.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        timesheet.status.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(timesheet.status),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}