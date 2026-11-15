Map<String, int> _counts(dynamic json, List<String> keys) {
  final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
  return {for (final k in keys) k: (map[k] as num?)?.toInt() ?? 0};
}

class TaskStatistics {
  final int total;
  final Map<String, int> byStatus; // todo, in_progress, completed
  final Map<String, int> byPriority; // low, medium, high
  final double completionRate; // phần trăm hoàn thành (0 - 100)

  TaskStatistics({
    required this.total,
    required this.byStatus,
    required this.byPriority,
    required this.completionRate,
  });

  factory TaskStatistics.fromJson(Map<String, dynamic> json) => TaskStatistics(
        total: (json['total'] as num?)?.toInt() ?? 0,
        byStatus: _counts(json['byStatus'], ['todo', 'in_progress', 'completed']),
        byPriority: _counts(json['byPriority'], ['low', 'medium', 'high']),
        completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      );
}

// Số việc theo trạng thái của một nhóm công việc
class StatusCounts {
  final int total;
  final int active; // chưa hoàn thành
  final Map<String, int> byStatus;

  StatusCounts({required this.total, required this.active, required this.byStatus});

  factory StatusCounts.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return StatusCounts(
      total: (map['total'] as num?)?.toInt() ?? 0,
      active: (map['active'] as num?)?.toInt() ?? 0,
      byStatus: _counts(map['byStatus'], ['todo', 'in_progress', 'completed']),
    );
  }
}

class AssignmentStatistics {
  final StatusCounts assignedToMe; // được giao cho tôi
  final StatusCounts primaryResponsible; // tôi phụ trách chính
  final StatusCounts assignedByMe; // tôi đã giao cho người khác

  AssignmentStatistics({
    required this.assignedToMe,
    required this.primaryResponsible,
    required this.assignedByMe,
  });

  factory AssignmentStatistics.fromJson(Map<String, dynamic> json) =>
      AssignmentStatistics(
        assignedToMe: StatusCounts.fromJson(json['assignedToMe']),
        primaryResponsible: StatusCounts.fromJson(json['primaryResponsible']),
        assignedByMe: StatusCounts.fromJson(json['assignedByMe']),
      );
}

class DeadlineTask {
  final String id;
  final String title;
  final String status;
  final String priority;
  final DateTime? dueDate;

  DeadlineTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueDate,
  });

  factory DeadlineTask.fromJson(Map<String, dynamic> json) => DeadlineTask(
        id: json['_id'].toString(),
        title: json['title'] ?? '',
        status: json['status'] ?? 'todo',
        priority: json['priority'] ?? 'medium',
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.tryParse(json['dueDate'].toString())?.toLocal(),
      );
}

class DeadlineGroup {
  final int count; // tổng số việc (có thể nhiều hơn số việc trong danh sách)
  final List<DeadlineTask> tasks;

  DeadlineGroup({required this.count, required this.tasks});

  factory DeadlineGroup.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final list = (map['tasks'] as List?) ?? [];
    return DeadlineGroup(
      count: (map['count'] as num?)?.toInt() ?? 0,
      tasks: list
          .whereType<Map<String, dynamic>>()
          .map(DeadlineTask.fromJson)
          .toList(),
    );
  }
}

class DeadlineStatistics {
  final int days;
  final DeadlineGroup dueSoon;
  final DeadlineGroup overdue;
  final int noDueDate;

  DeadlineStatistics({
    required this.days,
    required this.dueSoon,
    required this.overdue,
    required this.noDueDate,
  });

  factory DeadlineStatistics.fromJson(Map<String, dynamic> json) =>
      DeadlineStatistics(
        days: (json['days'] as num?)?.toInt() ?? 7,
        dueSoon: DeadlineGroup.fromJson(json['dueSoon']),
        overdue: DeadlineGroup.fromJson(json['overdue']),
        noDueDate: (json['noDueDate'] as num?)?.toInt() ?? 0,
      );
}

class StatisticsSummary {
  final TaskStatistics tasks;
  final AssignmentStatistics assignments;
  final DeadlineStatistics deadlines;

  StatisticsSummary({
    required this.tasks,
    required this.assignments,
    required this.deadlines,
  });
}
