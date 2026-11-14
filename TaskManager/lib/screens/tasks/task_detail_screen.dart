import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = TaskService();

  Task? _task;
  bool _loading = true;
  String? _error;
  bool _changed = false; // báo cho màn danh sách biết cần tải lại
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await _service.getTask(widget.taskId);
      if (!mounted) return;
      setState(() => _task = task);
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

  Future<void> _changeStatus(String status) async {
    final task = _task;
    if (task == null || task.status == status || _busy) return;

    setState(() => _busy = true);
    try {
      final updated = await _service.updateStatus(task.id, status);
      if (!mounted) return;
      setState(() {
        _task = updated;
        _changed = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final task = _task;
    if (task == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _delete() async {
    final task = _task;
    if (task == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: Text('Bạn có chắc muốn xóa "${task.title}"? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _service.deleteTask(task.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          actions: [
            if (task != null && task.permissions.canEdit)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Chỉnh sửa',
                onPressed: _busy ? null : _edit,
              ),
            if (task != null && task.permissions.canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xóa',
                onPressed: _busy ? null : _delete,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _task == null) return const LoadingView();
    if (_error != null || _task == null) {
      return ErrorView(message: _error ?? 'Không tải được công việc', onRetry: _load);
    }

    final task = _task!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          task.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(status: task.status),
            PriorityBadge(priority: task.priority),
          ],
        ),
        const SizedBox(height: 20),
        _section('Mô tả'),
        Text(task.description.isEmpty ? 'Không có mô tả' : task.description),
        const SizedBox(height: 20),
        _section('Thời gian'),
        _infoRow(Icons.play_arrow, 'Bắt đầu', DateFormatter.date(task.startDate)),
        _infoRow(
          Icons.event,
          'Hạn hoàn thành',
          '${DateFormatter.date(task.dueDate)}${task.isOverdue ? ' (quá hạn)' : ''}',
          color: task.isOverdue ? Colors.red : null,
        ),
        _infoRow(Icons.schedule, 'Ngày tạo', DateFormatter.dateTime(task.createdAt)),
        const SizedBox(height: 20),
        _section('Người liên quan'),
        _infoRow(Icons.person, 'Người tạo', task.createdBy?.fullName ?? 'Không rõ'),
        _infoRow(
          Icons.star_outline,
          'Phụ trách chính',
          task.primaryAssignee?.fullName ?? 'Chưa có',
        ),
        _infoRow(
          Icons.groups_outlined,
          'Được giao',
          task.assignees.isEmpty
              ? 'Chưa giao cho ai'
              : task.assignees.map((u) => u.fullName).join(', '),
        ),
        if (task.myRole != null)
          _infoRow(Icons.badge_outlined, 'Vai trò của bạn', Task.roleLabels[task.myRole] ?? ''),
        const SizedBox(height: 20),
        _section('Cập nhật trạng thái'),
        if (task.permissions.canChangeStatus)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in Task.statuses)
                ChoiceChip(
                  label: Text(Task.statusLabel(s)),
                  selected: task.status == s,
                  onSelected: _busy ? null : (_) => _changeStatus(s),
                ),
            ],
          )
        else
          Text(
            'Bạn chỉ có quyền xem công việc này.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
