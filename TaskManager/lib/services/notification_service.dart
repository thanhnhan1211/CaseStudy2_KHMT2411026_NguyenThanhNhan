import '../models/notification.dart';
import 'api_client.dart';

class NotificationList {
  final List<AppNotification> items;
  final int unreadCount;

  NotificationList({required this.items, required this.unreadCount});
}

class NotificationService {
  final ApiClient _api = ApiClient();

  Future<NotificationList> getNotifications({bool unreadOnly = false}) async {
    final data = await _api.get('/notifications', query: {
      'limit': '100',
      if (unreadOnly) 'unread': 'true',
    });
    final list = (data['notifications'] as List?) ?? [];
    return NotificationList(
      items: list
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> getUnreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all');
  }
}
