import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/task_share_service.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';

// Quản lý chia sẻ. Người tạo được thêm, đổi quyền, thu hồi; người khác chỉ xem.
class TaskSharingScreen extends StatefulWidget {
  final Task task;
  const TaskSharingScreen({super.key, required this.task});

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  final _service = TaskShareService();

  List<TaskShare> _shares = [];
  List<User> _selected = [];
  String _permission = 'viewer';
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  bool get _canManage => widget.task.permissions.canManage;

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
      final list = await _service.getShares(widget.task.id);
      if (!mounted) return;
      setState(() => _shares = list);
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

  Future<void> _run(
    Future<List<TaskShare>> Function() action, {
    String? success,
    bool clearSelection = false,
  }) async {
    setState(() => _busy = true);
    try {
      final list = await action();
      if (!mounted) return;
      setState(() {
        _shares = list;
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

  Future<void> _share() async {
    if (_selected.isEmpty) return;
    await _run(
      () => _service.share(
        widget.task.id,
        _selected.map((u) => u.id).toList(),
        _permission,
      ),
      success: 'Đã chia sẻ công việc',
      clearSelection: true,
    );
  }

  Future<void> _changePermission(TaskShare share, String permission) async {
    if (share.permission == permission) return;
    await _run(
      () => _service.updatePermission(widget.task.id, share.id, permission),
      success: 'Đã đổi quyền của ${share.user.fullName}',
    );
  }

  Future<void> _revoke(TaskShare share) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thu hồi quyền'),
        content: Text(
          '${share.user.fullName} sẽ không còn truy cập được công việc này. Tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(
      () => _service.revoke(widget.task.id, share.id),
      success: 'Đã thu hồi quyền',
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
        appBar: AppBar(
          title: Text(_canManage ? 'Quản lý chia sẻ' : 'Người được chia sẻ'),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      );

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final owner = widget.task.createdBy;
    final excluded = <String>{
      if (owner != null) owner.id,
      ..._shares.map((s) => s.user.id),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.task.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _label('Người có quyền truy cập'),
        const SizedBox(height: 4),
        if (owner != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(owner.fullName.isNotEmpty ? owner.fullName[0].toUpperCase() : '?'),
            ),
            title: Text(owner.fullName),
            subtitle: Text(owner.email),
            trailing: const Text('Người tạo'),
          ),
        if (_shares.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Chưa chia sẻ cho ai'),
          ),
        for (final share in _shares)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(
                share.user.fullName.isNotEmpty ? share.user.fullName[0].toUpperCase() : '?',
              ),
            ),
            title: Text(share.user.fullName),
            subtitle: Text(share.user.email),
            trailing: _canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: share.permission,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final p in TaskShare.permissions)
                            DropdownMenuItem(
                              value: p,
                              child: Text(TaskShare.permissionLabel(p)),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value != null) _changePermission(share, value);
                              },
                      ),
                      IconButton(
                        tooltip: 'Thu hồi quyền',
                        icon: const Icon(Icons.close),
                        onPressed: _busy ? null : () => _revoke(share),
                      ),
                    ],
                  )
                : Text(TaskShare.permissionLabel(share.permission)),
          ),
        if (_canManage) ...[
          const Divider(height: 32),
          _label('Chia sẻ thêm cho'),
          const SizedBox(height: 8),
          UserSelector(
            selected: _selected,
            excludeIds: excluded,
            onChanged: (users) => setState(() => _selected = users),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'viewer',
                label: Text('Chỉ xem'),
                icon: Icon(Icons.visibility_outlined),
              ),
              ButtonSegment(
                value: 'editor',
                label: Text('Chỉnh sửa'),
                icon: Icon(Icons.edit_outlined),
              ),
            ],
            selected: {_permission},
            onSelectionChanged: (set) => setState(() => _permission = set.first),
          ),
          const SizedBox(height: 8),
          Text(
            _permission == 'viewer'
                ? 'Chỉ xem: xem nội dung, không sửa được.'
                : 'Chỉnh sửa: sửa thông tin và đổi trạng thái, nhưng không xóa hay quản lý chia sẻ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_busy || _selected.isEmpty) ? null : _share,
            icon: const Icon(Icons.share),
            label: Text('Chia sẻ (${_selected.length})'),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'Chỉ người tạo công việc mới được thêm, đổi quyền hoặc thu hồi chia sẻ.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
