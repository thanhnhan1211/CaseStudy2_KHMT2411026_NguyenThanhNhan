import '../models/assignee.dart';
import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient _api = ApiClient();

  Future<List<Task>> getTasks({
    String scope = 'all',
    String? status,
    String? priority,
    String? q,
    String sortBy = 'createdAt',
    String? order,
  }) async {
    final query = <String, String>{
      'scope': scope,
      'sortBy': sortBy,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (order != null) 'order': order,
    };
    final data = await _api.get('/tasks', query: query);
    final list = (data['tasks'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  Future<Task> getTask(String id) async {
    final data = await _api.get('/tasks/$id');
    return Task.fromJson(data['task']);
  }

  Future<Task> createTask(Map<String, dynamic> fields) async {
    final data = await _api.post('/tasks', body: fields);
    return Task.fromJson(data['task']);
  }

  Future<Task> updateTask(String id, Map<String, dynamic> fields) async {
    final data = await _api.put('/tasks/$id', body: fields);
    return Task.fromJson(data['task']);
  }

  Future<Task> updateStatus(String id, String status) async {
    final data = await _api.patch('/tasks/$id/status', body: {'status': status});
    return Task.fromJson(data['task']);
  }

  Future<void> deleteTask(String id) async {
    await _api.delete('/tasks/$id');
  }

  // ---------- Giao việc ----------
  List<Assignee> _parseAssignees(Map<String, dynamic> data) {
    final list = (data['assignees'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Assignee.fromJson)
        .toList();
  }

  Future<List<Assignee>> getAssignees(String taskId) async =>
      _parseAssignees(await _api.get('/tasks/$taskId/assignees'));

  Future<List<Assignee>> assign(String taskId, List<String> userIds) async =>
      _parseAssignees(
        await _api.post('/tasks/$taskId/assignees', body: {'userIds': userIds}),
      );

  Future<List<Assignee>> setPrimary(
    String taskId,
    String userId,
    bool isPrimary,
  ) async =>
      _parseAssignees(
        await _api.patch(
          '/tasks/$taskId/assignees/$userId',
          body: {'isPrimary': isPrimary},
        ),
      );

  Future<List<Assignee>> removeAssignee(String taskId, String userId) async =>
      _parseAssignees(await _api.delete('/tasks/$taskId/assignees/$userId'));
}
