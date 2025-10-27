import 'package:flutter/material.dart';

class StatusChipsWidget extends StatelessWidget {
  final String status;
  final bool isCompact;

  const StatusChipsWidget({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();

    return _buildStatusChip(status);
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isCompact ? 12 : 14,
              color: color,
            ),
            SizedBox(width: isCompact ? 2 : 4),
          ],
          Text(
            status,
            style: TextStyle(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
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

  IconData? _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.play_circle_outline;
      case 'completed':
        return Icons.check_circle_outline;
      case 'on hold':
        return Icons.pause_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'planning':
        return Icons.assignment_outlined;
      default:
        return null;
    }
  }
}
