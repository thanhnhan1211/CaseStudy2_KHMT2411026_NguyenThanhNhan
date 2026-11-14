import '../models/task_share.dart';
import 'api_client.dart';

class TaskShareService {
  final ApiClient _api = ApiClient();

  List<TaskShare> _parse(Map<String, dynamic> data) {
    final list = (data['shares'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .where((e) => e['user'] is Map<String, dynamic>) // bỏ người đã bị xóa tài khoản
        .map(TaskShare.fromJson)
        .toList();
  }

  Future<List<TaskShare>> getShares(String taskId) async =>
      _parse(await _api.get('/tasks/$taskId/shares'));

  Future<List<TaskShare>> share(
    String taskId,
    List<String> userIds,
    String permission,
  ) async =>
      _parse(await _api.post(
        '/tasks/$taskId/shares',
        body: {'userIds': userIds, 'permission': permission},
      ));

  Future<List<TaskShare>> updatePermission(
    String taskId,
    String shareId,
    String permission,
  ) async =>
      _parse(await _api.patch(
        '/tasks/$taskId/shares/$shareId',
        body: {'permission': permission},
      ));

  Future<List<TaskShare>> revoke(String taskId, String shareId) async =>
      _parse(await _api.delete('/tasks/$taskId/shares/$shareId'));
}
