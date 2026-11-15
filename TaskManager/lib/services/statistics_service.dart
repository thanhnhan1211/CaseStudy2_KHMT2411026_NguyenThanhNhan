import '../models/statistics.dart';
import 'api_client.dart';

class StatisticsService {
  final ApiClient _api = ApiClient();

  Future<TaskStatistics> getTaskStatistics({String scope = 'all'}) async =>
      TaskStatistics.fromJson(
        await _api.get('/statistics/tasks', query: {'scope': scope}),
      );

  Future<AssignmentStatistics> getAssignmentStatistics() async =>
      AssignmentStatistics.fromJson(await _api.get('/statistics/assignments'));

  Future<DeadlineStatistics> getDeadlineStatistics({
    int days = 7,
    String scope = 'all',
  }) async =>
      DeadlineStatistics.fromJson(
        await _api.get(
          '/statistics/deadlines',
          query: {'days': '$days', 'scope': scope},
        ),
      );

  // Tải cả ba nhóm số liệu cùng lúc
  Future<StatisticsSummary> getSummary({int days = 7}) async {
    final results = await Future.wait<Object>([
      getTaskStatistics(),
      getAssignmentStatistics(),
      getDeadlineStatistics(days: days),
    ]);
    return StatisticsSummary(
      tasks: results[0] as TaskStatistics,
      assignments: results[1] as AssignmentStatistics,
      deadlines: results[2] as DeadlineStatistics,
    );
  }
}
