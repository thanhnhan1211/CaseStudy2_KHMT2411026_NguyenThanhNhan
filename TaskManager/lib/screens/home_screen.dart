import 'package:flutter/material.dart';

import 'tasks/task_list_screen.dart';

// Màn hình chính sau khi đăng nhập: danh sách công việc
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const TaskListScreen();
}
