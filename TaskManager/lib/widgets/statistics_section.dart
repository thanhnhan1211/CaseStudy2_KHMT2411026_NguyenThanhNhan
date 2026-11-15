import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../models/task.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../services/api_client.dart';
import '../services/statistics_service.dart';
import '../utils/date_formatter.dart';
import '../utils/session.dart';

// Khối thống kê công việc, dùng trong màn hình "Cá nhân và thống kê"
class StatisticsSection extends StatefulWidget {
  const StatisticsSection({super.key});

  @override
  State<StatisticsSection> createState() => _StatisticsSectionState();
}

class _StatisticsSectionState extends State<StatisticsSection> {
  static const int _deadlineDays = 7;
  static const int _maxShown = 5; // số việc hiển thị tối đa trong mỗi nhóm hạn

  static const Map<String, Color> _statusColors = {
    'todo': Colors.grey,
    'in_progress': Colors.blue,
    'completed': Colors.green,
  };

  final _service = StatisticsService();

  StatisticsSummary? _summary;
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
      final summary = await _service.getSummary(days: _deadlineDays);
      if (!mounted) return;
      setState(() {
        _summary = summary;
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

  Future<void> _openTask(DeadlineTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    if (mounted) _load(showSpinner: false);
  }

  String _percent(double rate) =>
      '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%';

  String _dueText(DateTime? due, {required bool overdue}) {
    if (due == null) return 'Chưa đặt hạn';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (overdue) return diff < 0 ? 'Quá hạn ${-diff} ngày' : 'Quá hạn hôm nay';
    if (diff <= 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    return 'Còn $diff ngày';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Thống kê công việc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _load(),
            ),
          ],
        ),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading && _summary == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;
    return Column(
      children: [
        _statusCard(summary.tasks),
        _assignmentCard(summary.assignments),
        _deadlineCard(summary.deadlines),
      ],
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // ---------- Theo trạng thái ----------
  Widget _statusCard(TaskStatistics stats) {
    return _card('Theo trạng thái', Icons.pie_chart_outline, [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${stats.total}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('công việc'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${_percent(stats.completionRate)} hoàn thành',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _statusBar(stats),
      const SizedBox(height: 12),
      for (final status in Task.statuses)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: _statusColors[status]),
              const SizedBox(width: 8),
              Expanded(child: Text(Task.statusLabel(status))),
              Text(
                '${stats.byStatus[status] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      const Divider(height: 24),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final priority in ['high', 'medium', 'low'])
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                'Ưu tiên ${Task.priorityLabel(priority).toLowerCase()}: ${stats.byPriority[priority] ?? 0}',
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _statusBar(TaskStatistics stats) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: stats.total == 0
            ? Container(color: Colors.grey.shade300)
            : Row(
                children: [
                  for (final status in Task.statuses)
                    if ((stats.byStatus[status] ?? 0) > 0)
                      Expanded(
                        flex: stats.byStatus[status]!,
                        child: Container(color: _statusColors[status]),
                      ),
                ],
              ),
      ),
    );
  }

  // ---------- Được giao và phụ trách ----------
  Widget _assignmentCard(AssignmentStatistics stats) {
    Widget row(IconData icon, String label, StatusCounts counts) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(
              '${counts.total}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(
              width: 92,
              child: Text(
                counts.total == 0 ? '' : '  (${counts.active} chưa xong)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    return _card('Giao việc', Icons.assignment_ind_outlined, [
      row(Icons.inbox_outlined, 'Được giao cho tôi', stats.assignedToMe),
      row(Icons.star_outline, 'Tôi phụ trách chính', stats.primaryResponsible),
      row(Icons.send_outlined, 'Tôi đã giao cho người khác', stats.assignedByMe),
    ]);
  }

  // ---------- Hạn hoàn thành ----------
  Widget _deadlineCard(DeadlineStatistics stats) {
    return _card('Hạn hoàn thành', Icons.event_available_outlined, [
      _deadlineGroup(
        title: 'Quá hạn',
        group: stats.overdue,
        color: Colors.red,
        overdue: true,
        emptyText: 'Không có việc nào quá hạn',
      ),
      const SizedBox(height: 12),
      _deadlineGroup(
        title: 'Sắp đến hạn trong ${stats.days} ngày',
        group: stats.dueSoon,
        color: Colors.orange,
        overdue: false,
        emptyText: 'Không có việc nào sắp đến hạn',
      ),
      if (stats.noDueDate > 0) ...[
        const SizedBox(height: 12),
        Text(
          '${stats.noDueDate} việc chưa đặt hạn hoàn thành',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    ]);
  }

  Widget _deadlineGroup({
    required String title,
    required DeadlineGroup group,
    required Color color,
    required bool overdue,
    required String emptyText,
  }) {
    final shown = group.tasks.take(_maxShown).toList();
    final hidden = group.count - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${group.count})',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        if (group.count == 0)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: Text(emptyText, style: TextStyle(color: Colors.grey.shade600)),
          ),
        for (final task in shown)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 18),
            title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${DateFormatter.date(task.dueDate)} • ${_dueText(task.dueDate, overdue: overdue)}',
              style: TextStyle(color: color),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openTask(task),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 2),
            child: Text(
              'và $hidden việc khác',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
