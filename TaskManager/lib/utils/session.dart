import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';

// Token hết hạn hoặc không hợp lệ: xóa token và quay về màn đăng nhập
Future<void> redirectToLogin(BuildContext context) async {
  await AuthService().logout();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Phiên đăng nhập đã hết hạn, hãy đăng nhập lại')),
  );
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
