import 'user.dart';

class TaskPermissions {
  final bool canEdit;
  final bool canChangeStatus;
  final bool canDelete;
  final bool canManage; // giao việc + quản lý chia sẻ

  const TaskPermissions({
    this.canEdit = false,
    this.canChangeStatus = false,
    this.canDelete = false,
    this.canManage = false,
  });

  factory TaskPermissions.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const TaskPermissions();
    return TaskPermissions(
      canEdit: json['canEdit'] == true,
      canChangeStatus: json['canChangeStatus'] == true,
      canDelete: json['canDelete'] == true,
      canManage: json['canManage'] == true,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String status; // todo | in_progress | completed
  final String priority; // low | medium | high
  final DateTime? startDate;
  final DateTime? dueDate;
  final User? createdBy;
  final List<User> assignees;
  final User? primaryAssignee;
  final DateTime? createdAt;
  final String? myRole; // owner | editor | assignee | viewer
  final TaskPermissions permissions;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.createdBy,
    this.assignees = const [],
    this.primaryAssignee,
    this.createdAt,
    this.myRole,
    this.permissions = const TaskPermissions(),
  });

  static const List<String> statuses = ['todo', 'in_progress', 'completed'];
  static const List<String> priorities = ['low', 'medium', 'high'];

  static const Map<String, String> statusLabels = {
    'todo': 'Chưa thực hiện',
    'in_progress': 'Đang thực hiện',
    'completed': 'Đã hoàn thành',
  };

  static const Map<String, String> priorityLabels = {
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
  };

  static const Map<String, String> roleLabels = {
    'owner': 'Người tạo',
    'editor': 'Được chia sẻ (chỉnh sửa)',
    'viewer': 'Được chia sẻ (chỉ xem)',
    'assignee': 'Người được giao',
  };

  static String statusLabel(String status) => statusLabels[status] ?? status;
  static String priorityLabel(String priority) =>
      priorityLabels[priority] ?? priority;

  bool get isCompleted => status == 'completed';

  bool get isOverdue =>
      dueDate != null && !isCompleted && dueDate!.isBefore(DateTime.now());

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static User? _user(dynamic value) =>
      value is Map<String, dynamic> ? User.fromJson(value) : null;

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['assigneeIds'];
    return Task(
      id: json['_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'todo',
      priority: json['priority'] ?? 'medium',
      startDate: _date(json['startDate']),
      dueDate: _date(json['dueDate']),
      createdBy: _user(json['createdBy']),
      assignees: rawAssignees is List
          ? rawAssignees.whereType<Map<String, dynamic>>().map(User.fromJson).toList()
          : <User>[],
      primaryAssignee: _user(json['primaryAssigneeId']),
      createdAt: _date(json['createdAt']),
      myRole: json['myRole'],
      permissions: TaskPermissions.fromJson(json['permissions']),
    );
  }
}
