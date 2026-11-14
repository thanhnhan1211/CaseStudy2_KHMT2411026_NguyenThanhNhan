import 'user.dart';

// Một người được giao việc, kèm cờ "phụ trách chính"
class Assignee {
  final User user;
  final bool isPrimary;

  Assignee({required this.user, required this.isPrimary});

  factory Assignee.fromJson(Map<String, dynamic> json) {
    return Assignee(
      user: User.fromJson(json),
      isPrimary: json['isPrimary'] == true,
    );
  }
}
