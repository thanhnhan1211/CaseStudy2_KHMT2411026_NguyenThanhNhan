import 'package:flutter/material.dart';

import '../../models/email_log.dart';
import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/email_log_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/session.dart';
import '../../widgets/loading_view.dart';

// Lịch sử gửi email của một công việc (chỉ người tạo xem được)
class EmailLogScreen extends StatefulWidget {
  final Task task;
  const EmailLogScreen({super.key, required this.task});

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  final _service = EmailLogService();

  List<EmailLog> _logs = [];
  bool _loading = true;
  String? _error;
  String? _retryingId;

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
      final logs = await _service.getLogs(widget.task.id);
      if (!mounted) return;
      setState(() {
        _logs = logs;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retry(EmailLog log) async {
    setState(() => _retryingId = log.id);
    try {
      final updated = await _service.retry(log.id);
      if (!mounted) return;
      setState(() {
        _logs = [for (final l in _logs) l.id == updated.id ? updated : l];
      });
      _showMessage(
        updated.status == 'sent'
            ? 'Đã gửi lại email thành công'
            : 'Gửi lại vẫn thất bại: ${updated.errorMessage}',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _retryingId = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử gửi email')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    if (_logs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 300,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa có email nào.\nEmail được gửi khi giao việc, chia sẻ, đổi hạn, hoàn thành hoặc sắp đến hạn.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = _logs[index];
          final color = _statusColor(log.status);
          return ListTile(
            title: Text(log.recipientEmail),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${EmailLog.eventLabels[log.eventType] ?? log.eventType} • '
                    '${DateFormatter.dateTime(log.createdAt)} • Lần thử: ${log.attempts}',
                  ),
                  if (log.status == 'failed' && log.errorMessage.isNotEmpty)
                    Text(
                      log.errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
            ),
            isThreeLine: log.status == 'failed',
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  EmailLog.statusLabels[log.status] ?? log.status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (log.canRetry)
                  _retryingId == log.id
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : InkWell(
                          onTap: _retryingId == null ? () => _retry(log) : null,
                          child: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Gửi lại',
                              style: TextStyle(color: Colors.indigo, fontSize: 13),
                            ),
                          ),
                        ),
              ],
            ),
          );
        },
      ),
    );
  }
}
