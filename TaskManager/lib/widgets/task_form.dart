import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../utils/date_formatter.dart';

// Form dùng chung cho màn hình Thêm và Sửa công việc
class TaskForm extends StatefulWidget {
  final Task? initial;
  final String submitLabel;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const TaskForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _startDate;
  DateTime? _dueDate;
  late String _priority;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.initial;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _startDate = task?.startDate;
    _dueDate = task?.dueDate;
    _priority = task?.priority ?? 'medium';
    _status = task?.status ?? 'todo';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickDate(_startDate);
    if (picked == null) return;
    setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickDue() async {
    final picked = await _pickDate(_dueDate);
    if (picked == null) return;
    // Hạn hoàn thành tính đến cuối ngày được chọn
    setState(
      () => _dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null && _dueDate != null && _dueDate!.isBefore(_startDate!)) {
      _showMessage('Hạn hoàn thành không được trước ngày bắt đầu');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': _priority,
        'status': _status,
        'startDate': _startDate?.toUtc().toIso8601String(),
        'dueDate': _dueDate?.toUtc().toIso8601String(),
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên công việc *',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Vui lòng nhập tên công việc';
              if (value.length > 200) return 'Tên không được quá 200 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().length > 2000 ? 'Mô tả không được quá 2000 ký tự' : null,
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Ngày bắt đầu',
            value: _startDate,
            onTap: _pickStart,
            onClear: () => setState(() => _startDate = null),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Hạn hoàn thành',
            value: _dueDate,
            onTap: _pickDue,
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'Mức độ ưu tiên',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in Task.priorities)
                DropdownMenuItem(value: p, child: Text(Task.priorityLabel(p))),
            ],
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in Task.statuses)
                DropdownMenuItem(value: s, child: Text(Task.statusLabel(s))),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event),
          suffixIcon: value == null
              ? null
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(DateFormatter.date(value)),
      ),
    );
  }
}
