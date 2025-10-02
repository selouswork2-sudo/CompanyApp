import 'package:flutter/material.dart';
import '../models/timesheet.dart';
import '../models/project.dart';
import '../models/plan.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class TimesheetListScreen extends StatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  State<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends State<TimesheetListScreen> {
  List<Map<String, dynamic>> _timesheets = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Pending, Approved, Rejected
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadTimesheets();
  }

  Future<void> _loadTimesheets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all timesheets with project and plan info
      final timesheetMaps = await DatabaseService.instance.query('timesheets');
      
      List<Map<String, dynamic>> timesheetsWithDetails = [];

      for (var timesheetMap in timesheetMaps) {
        final timesheet = Timesheet.fromMap(timesheetMap);
        
        // Get project info
        final projectMaps = await DatabaseService.instance.query(
          'projects',
          where: 'id = ?',
          whereArgs: [timesheet.projectId],
        );
        
        Project? project;
        if (projectMaps.isNotEmpty) {
          project = Project.fromMap(projectMaps.first);
        }

        // Get plan info if exists
        Plan? plan;
        if (timesheet.planId != null) {
          final planMaps = await DatabaseService.instance.query(
            'plans',
            where: 'id = ?',
            whereArgs: [timesheet.planId],
          );
          if (planMaps.isNotEmpty) {
            plan = Plan.fromMap(planMaps.first);
          }
        }

        timesheetsWithDetails.add({
          'timesheet': timesheet,
          'project': project,
          'plan': plan,
        });
      }

      // Sort by date (newest first)
      timesheetsWithDetails.sort((a, b) {
        final timesheetA = a['timesheet'] as Timesheet;
        final timesheetB = b['timesheet'] as Timesheet;
        return timesheetB.date.compareTo(timesheetA.date);
      });

      setState(() {
        _timesheets = timesheetsWithDetails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTimesheets {
    var filtered = _timesheets;

    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered.where((item) {
        final timesheet = item['timesheet'] as Timesheet;
        return timesheet.status.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Filter by date if selected
    if (_selectedDate != null) {
      filtered = filtered.where((item) {
        final timesheet = item['timesheet'] as Timesheet;
        return timesheet.date.year == _selectedDate!.year &&
               timesheet.date.month == _selectedDate!.month &&
               timesheet.date.day == _selectedDate!.day;
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warning;
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Timesheets'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimesheets,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Status Filter
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
                            final isSelected = _selectedFilter == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(status),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = status;
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                                checkmarkColor: AppTheme.primaryBlue,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date Filter
                Row(
                  children: [
                    const Text('Date:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate != null 
                                    ? _formatDate(_selectedDate!)
                                    : 'All dates',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (_selectedDate != null) ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: _clearDateFilter,
                                  child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Timesheets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTimesheets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No timesheets found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start tracking your work hours',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTimesheets.length,
                        itemBuilder: (context, index) {
                          final item = _filteredTimesheets[index];
                          final timesheet = item['timesheet'] as Timesheet;
                          final project = item['project'] as Project?;
                          final plan = item['plan'] as Plan?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    children: [
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(timesheet.status),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          timesheet.status.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Date
                                      Text(
                                        _formatDate(timesheet.date),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Project and Job info
                                  Row(
                                    children: [
                                      const Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          project?.name ?? 'Unknown Project',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  if (plan != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.work, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          plan.jobNumber,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Time info
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Start Time',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              _formatTime(timesheet.startTime),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'End Time',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              _formatTime(timesheet.endTime),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Total',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              timesheet.totalHoursFormatted,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Notes
                                  if (timesheet.notes != null && timesheet.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Notes:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timesheet.notes!,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
