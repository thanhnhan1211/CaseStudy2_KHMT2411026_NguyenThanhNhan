import '../models/email_log.dart';
import 'api_client.dart';

class EmailLogService {
  final ApiClient _api = ApiClient();

  Future<List<EmailLog>> getLogs(String taskId) async {
    final data = await _api.get('/tasks/$taskId/email-logs');
    final list = (data['emailLogs'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmailLog.fromJson)
        .toList();
  }

  // Trả về bản ghi sau khi thử gửi lại (có thể vẫn failed)
  Future<EmailLog> retry(String logId) async {
    final data = await _api.post('/email-logs/$logId/retry');
    return EmailLog.fromJson(data['emailLog'] as Map<String, dynamic>);
  }
}
