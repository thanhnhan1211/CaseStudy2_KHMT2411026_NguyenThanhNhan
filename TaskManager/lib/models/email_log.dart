class EmailLog {
  final String id;
  final String recipientEmail;
  final String eventType;
  final String subject;
  final String status; // pending | sent | failed
  final int attempts;
  final String errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;

  EmailLog({
    required this.id,
    required this.recipientEmail,
    required this.eventType,
    required this.subject,
    required this.status,
    required this.attempts,
    required this.errorMessage,
    this.sentAt,
    this.createdAt,
  });

  static const int maxAttempts = 3;

  static const Map<String, String> statusLabels = {
    'pending': 'Đang gửi',
    'sent': 'Đã gửi',
    'failed': 'Thất bại',
  };

  static const Map<String, String> eventLabels = {
    'task_assigned': 'Giao việc',
    'task_shared': 'Chia sẻ',
    'due_date_changed': 'Đổi hạn',
    'task_completed': 'Hoàn thành',
    'task_reminder': 'Nhắc việc',
  };

  bool get canRetry => status == 'failed' && attempts < maxAttempts;

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory EmailLog.fromJson(Map<String, dynamic> json) {
    return EmailLog(
      id: json['_id'].toString(),
      recipientEmail: json['recipientEmail'] ?? '',
      eventType: json['eventType'] ?? '',
      subject: json['subject'] ?? '',
      status: json['status'] ?? 'pending',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage'] ?? '',
      sentAt: _date(json['sentAt']),
      createdAt: _date(json['createdAt']),
    );
  }
}
