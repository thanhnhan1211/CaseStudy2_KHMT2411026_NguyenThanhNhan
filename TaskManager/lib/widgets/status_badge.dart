import 'package:flutter/material.dart';

import '../models/task.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  MaterialColor get _color {
    switch (status) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        Task.statusLabel(status),
        style: TextStyle(fontSize: 12, color: _color.shade800),
      ),
    );
  }
}
