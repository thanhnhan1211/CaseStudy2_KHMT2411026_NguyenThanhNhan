import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskCreateScreen extends StatelessWidget {
  const TaskCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm công việc')),
      body: TaskForm(
        submitLabel: 'Tạo công việc',
        onSubmit: (data) async {
          await TaskService().createTask(data);
          if (!context.mounted) return;
          Navigator.of(context).pop(true);
        },
      ),
    );
  }
}
