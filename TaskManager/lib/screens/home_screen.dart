import 'package:flutter/material.dart';

import 'profile/profile_screen.dart';

// Màn hình tạm sau khi đăng nhập.
// Ở nhóm B, thay phần body bằng TaskListScreen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Cá nhân',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: const Center(child: Text('Danh sách công việc (làm ở nhóm B)')),
    );
  }
}
