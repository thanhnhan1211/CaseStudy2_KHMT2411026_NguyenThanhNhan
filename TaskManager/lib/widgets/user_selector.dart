import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

// Ô tìm và chọn nhiều người dùng (theo tên hoặc email)
class UserSelector extends StatefulWidget {
  final List<User> selected;
  final ValueChanged<List<User>> onChanged;
  final Set<String> excludeIds; // người không hiện trong kết quả tìm

  const UserSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.excludeIds = const {},
  });

  @override
  State<UserSelector> createState() => _UserSelectorState();
}

class _UserSelectorState extends State<UserSelector> {
  final _controller = TextEditingController();
  final _service = UserService();
  Timer? _debounce;
  int _requestId = 0;

  List<User> _results = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);

    if (query.length < 2) {
      _requestId++;
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service.search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() => _results = users);
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isSelected(User user) => widget.selected.any((s) => s.id == user.id);

  void _toggle(User user) {
    final list = [...widget.selected];
    if (_isSelected(user)) {
      list.removeWhere((s) => s.id == user.id);
    } else {
      list.add(user);
    }
    widget.onChanged(list);
  }

  String _initial(User user) =>
      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final visible =
        _results.where((u) => !widget.excludeIds.contains(u.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final user in widget.selected)
                InputChip(
                  avatar: CircleAvatar(child: Text(_initial(user))),
                  label: Text(user.fullName),
                  onDeleted: () => _toggle(user),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc email',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 4),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          )
        else if (_query.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nhập ít nhất 2 ký tự để tìm',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else if (!_loading && visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Không tìm thấy người dùng phù hợp',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        for (final user in visible)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(_initial(user))),
            title: Text(user.fullName),
            subtitle: Text(user.email),
            trailing: Icon(
              _isSelected(user) ? Icons.check_circle : Icons.add_circle_outline,
              color: _isSelected(user) ? Colors.green : null,
            ),
            onTap: () => _toggle(user),
          ),
      ],
    );
  }
}
