import 'package:flutter/material.dart';

import '../../models/assignee.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';

// Màn hình giao công việc (chỉ người tạo mở được)
class AssignTaskScreen extends StatefulWidget {
  final Task task;
  const AssignTaskScreen({super.key, required this.task});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _service = TaskService();

  List<Assignee> _assignees = [];
  List<User> _selected = [];
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

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
      final list = await _service.getAssignees(widget.task.id);
      if (!mounted) return;
      setState(() => _assignees = list);
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

  // Chạy một thao tác ghi, cập nhật danh sách từ kết quả trả về
  Future<void> _run(
    Future<List<Assignee>> Function() action, {
    String? success,
    bool clearSelection = false,
  }) async {
    setState(() => _busy = true);
    try {
      final list = await action();
      if (!mounted) return;
      setState(() {
        _assignees = list;
        _changed = true;
        if (clearSelection) _selected = [];
      });
      if (success != null) _showMessage(success);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await redirectToLogin(context);
        return;
      }
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    if (_selected.isEmpty) return;
    await _run(
      () => _service.assign(widget.task.id, _selected.map((u) => u.id).toList()),
      success: 'Đã giao việc',
      clearSelection: true,
    );
  }

  Future<void> _togglePrimary(Assignee assignee) => _run(
        () => _service.setPrimary(
          widget.task.id,
          assignee.user.id,
          !assignee.isPrimary,
        ),
      );

  Future<void> _remove(Assignee assignee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy giao việc'),
        content: Text('Bỏ ${assignee.user.fullName} khỏi công việc này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(
      () => _service.removeAssignee(widget.task.id, assignee.user.id),
      success: 'Đã hủy giao việc',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Giao việc')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.task.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'Người đang được giao (${_assignees.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        if (_assignees.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Chưa giao cho ai'),
          ),
        for (final a in _assignees)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(
                a.user.fullName.isNotEmpty ? a.user.fullName[0].toUpperCase() : '?',
              ),
            ),
            title: Text(a.user.fullName),
            subtitle: Text(a.isPrimary ? '${a.user.email}\nPhụ trách chính' : a.user.email),
            isThreeLine: a.isPrimary,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: a.isPrimary ? 'Bỏ phụ trách chính' : 'Đặt làm phụ trách chính',
                  icon: Icon(
                    a.isPrimary ? Icons.star : Icons.star_border,
                    color: a.isPrimary ? Colors.amber : null,
                  ),
                  onPressed: _busy ? null : () => _togglePrimary(a),
                ),
                IconButton(
                  tooltip: 'Hủy giao việc',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: _busy ? null : () => _remove(a),
                ),
              ],
            ),
          ),
        const Divider(height: 32),
        Text(
          'Giao thêm cho',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        UserSelector(
          selected: _selected,
          excludeIds: _assignees.map((a) => a.user.id).toSet(),
          onChanged: (users) => setState(() => _selected = users),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_busy || _selected.isEmpty) ? null : _assign,
          icon: const Icon(Icons.person_add_alt),
          label: Text('Giao việc (${_selected.length})'),
        ),
      ],
    );
  }
}
