import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/task_card.dart';
import '../profile/profile_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  static const Map<String, String> _scopes = {
    'all': 'Tất cả',
    'created': 'Của tôi',
    'assigned': 'Được giao',
    'shared': 'Được chia sẻ',
  };

  static const Map<String, String> _sorts = {
    'createdAt': 'Mới tạo',
    'dueDate': 'Hạn hoàn thành',
    'priority': 'Mức độ ưu tiên',
  };

  final _service = TaskService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0; // bỏ qua kết quả của request cũ

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  String _scope = 'all';
  String? _status;
  String? _priority;
  String _sortBy = 'createdAt';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final requestId = ++_requestId;
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tasks = await _service.getTasks(
        scope: _scope,
        status: _status,
        priority: _priority,
        q: _searchController.text,
        sortBy: _sortBy,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _tasks = tasks;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      if (e.statusCode == 401) {
        await redirectToLogin(context);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(showSpinner: false),
    );
  }

  Future<void> _openFilterSheet() async {
    String? status = _status;
    String? priority = _priority;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lọc công việc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Trạng thái'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in Task.statuses)
                    ChoiceChip(
                      label: Text(Task.statusLabel(s)),
                      selected: status == s,
                      onSelected: (sel) => setSheet(() => status = sel ? s : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Mức độ ưu tiên'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in Task.priorities)
                    ChoiceChip(
                      label: Text(Task.priorityLabel(p)),
                      selected: priority == p,
                      onSelected: (sel) => setSheet(() => priority = sel ? p : null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setSheet(() {
                      status = null;
                      priority = null;
                    }),
                    child: const Text('Xóa bộ lọc'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (applied == true) {
      setState(() {
        _status = status;
        _priority = priority;
      });
      _load();
    }
  }

  Future<void> _openDetail(Task task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    if (changed == true) _load(showSpinner: false);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
    );
    if (created == true) _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _status != null || _priority != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sắp xếp',
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() => _sortBy = value);
              _load();
            },
            itemBuilder: (context) => [
              for (final entry in _sorts.entries)
                PopupMenuItem(value: entry.key, child: Text('Sắp xếp: ${entry.value}')),
            ],
          ),
          IconButton(
            icon: Icon(
              hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: hasFilter ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Lọc',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Cá nhân',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên công việc',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          _load(showSpinner: false);
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final entry in _scopes.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _scope == entry.key,
                      onSelected: (_) {
                        setState(() => _scope = entry.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_status != null)
                      InputChip(
                        label: Text(Task.statusLabel(_status!)),
                        onDeleted: () {
                          setState(() => _status = null);
                          _load();
                        },
                      ),
                    if (_priority != null)
                      InputChip(
                        label: Text('Ưu tiên: ${Task.priorityLabel(_priority!)}'),
                        onDeleted: () {
                          setState(() => _priority = null);
                          _load();
                        },
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView(message: 'Đang tải công việc...');

    // Bọc trong ListView để vẫn kéo xuống làm mới được khi lỗi hoặc rỗng
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 300,
              child: ErrorView(message: _error!, onRetry: _load),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      final filtering = _status != null ||
          _priority != null ||
          _searchController.text.trim().isNotEmpty ||
          _scope != 'all';
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  filtering
                      ? 'Không có công việc phù hợp'
                      : 'Chưa có công việc nào.\nBấm "Thêm" để tạo công việc đầu tiên.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return TaskCard(task: task, onTap: () => _openDetail(task));
        },
      ),
    );
  }
}
