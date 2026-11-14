import 'user.dart';

// Một bản ghi chia sẻ công việc cho một người
class TaskShare {
  final String id;
  final User user;
  final String permission; // viewer | editor
  final User? sharedBy;
  final DateTime? createdAt;

  TaskShare({
    required this.id,
    required this.user,
    required this.permission,
    this.sharedBy,
    this.createdAt,
  });

  static const List<String> permissions = ['viewer', 'editor'];

  static const Map<String, String> permissionLabels = {
    'viewer': 'Chỉ xem',
    'editor': 'Chỉnh sửa',
  };

  static String permissionLabel(String permission) =>
      permissionLabels[permission] ?? permission;

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    final sharedBy = json['sharedBy'];
    return TaskShare(
      id: json['_id'].toString(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      permission: json['permission'] ?? 'viewer',
      sharedBy: sharedBy is Map<String, dynamic> ? User.fromJson(sharedBy) : null,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
    );
  }
}
