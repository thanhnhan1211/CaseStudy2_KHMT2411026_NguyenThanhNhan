import 'package:flutter/material.dart';

import '../../models/notification.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();

  List<AppNotification> _items = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _unreadCount = result.unreadCount;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await redirectToLogin(context);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      // Cập nhật giao diện ngay, rồi báo server
      setState(() {
        _items = [
          for (final n in _items)
            n.id == notification.id ? n.copyWith(isRead: true) : n,
        ];
        if (_unreadCount > 0) _unreadCount -= 1;
      });
      try {
        await _service.markRead(notification.id);
      } on ApiException catch (_) {
        // lỗi mạng: lần tải sau sẽ đồng bộ lại
      }
    }

    if (!mounted || notification.taskId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: notification.taskId),
      ),
    );
    if (mounted) _load(showSpinner: false);
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'share_updated':
        return Icons.vpn_key_outlined;
      case 'due_date_changed':
        return Icons.event_repeat;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_reminder':
        return Icons.alarm;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'task_completed':
        return Colors.green;
      case 'task_reminder':
        return Colors.orange;
      case 'due_date_changed':
        return Colors.deepOrange;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _unreadCount > 0 ? _markAllRead : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 300,
              child: Center(child: Text('Chưa có thông báo nào')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final n = _items[index];
          return ListTile(
            tileColor: n.isRead
                ? null
                : Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
            leading: CircleAvatar(
              backgroundColor: _color(n.type).withAlpha(30),
              child: Icon(_icon(n.type), color: _color(n.type)),
            ),
            title: Text(
              n.title,
              style: TextStyle(
                fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${n.message}\n${DateFormatter.relative(n.createdAt)}'),
            ),
            isThreeLine: true,
            trailing: n.isRead
                ? null
                : const Icon(Icons.circle, size: 10, color: Colors.indigo),
            onTap: () => _open(n),
          );
        },
      ),
    );
  }
}
