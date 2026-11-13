import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _StartGate(),
    );
  }
}

// Kiểm tra token đã lưu: còn hợp lệ -> vào Home, ngược lại -> Đăng nhập
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> {
  final _authService = AuthService();
  late final Future<bool> _check = _checkLogin();

  Future<bool> _checkLogin() async {
    if (!await _authService.isLoggedIn()) return false;
    try {
      await _authService.getMe();
      return true;
    } on AuthException catch (e) {
      // Token hết hạn/không hợp lệ hoặc không kết nối được -> về màn đăng nhập
      await _authService.logout();
      debugPrint('Auto-login failed: ${e.message}');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
