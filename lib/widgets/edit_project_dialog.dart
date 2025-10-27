import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EditProjectDialog extends StatefulWidget {
  final String currentName;
  final String currentAddress;
  final String currentStatus;

  const EditProjectDialog({
    super.key,
    required this.currentName,
    required this.currentAddress,
    required this.currentStatus,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late String _selectedStatus;

  final List<String> _availableStatuses = [
    'Active',
    'Completed',
    'On Hold',
    'Planning',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    print('🔍 DEBUG EditProjectDialog initState');
    print('  currentName: ${widget.currentName}');
    print('  currentAddress: ${widget.currentAddress}');
    print('  currentStatus: ${widget.currentStatus}');
    
    _nameController = TextEditingController(text: widget.currentName);
    _addressController = TextEditingController(text: widget.currentAddress);
    _selectedStatus = widget.currentStatus;
    
    print('  _selectedStatus initialized to: $_selectedStatus');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _selectStatus(String status) {
    print('🔍 DEBUG _selectStatus called with: $status');
    setState(() {
      _selectedStatus = status;
    });
    print('🔍 DEBUG _selectedStatus updated to: $_selectedStatus');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Project Address
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Status Selection
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableStatuses.map((status) {
                final isSelected = _selectedStatus == status;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) => _selectStatus(status),
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryBlue,
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            print('🔍 DEBUG EditProjectDialog Update button pressed');
            print('  Name: "${_nameController.text.trim()}"');
            print('  Address: "${_addressController.text.trim()}"');
            print('  Status: "$_selectedStatus"');
            
            // Remove validation for now - just close dialog
            print('🔍 DEBUG Closing dialog with result');
            Navigator.of(context).pop({
              'name': _nameController.text.trim(),
              'address': _addressController.text.trim(),
              'status': _selectedStatus,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
