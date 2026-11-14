import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskEditScreen extends StatelessWidget {
  final Task task;
  const TaskEditScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa công việc')),
      body: TaskForm(
        initial: task,
        submitLabel: 'Lưu thay đổi',
        onSubmit: (data) async {
          await TaskService().updateTask(task.id, data);
          if (!context.mounted) return;
          Navigator.of(context).pop(true);
        },
      ),
    );
  }
}
