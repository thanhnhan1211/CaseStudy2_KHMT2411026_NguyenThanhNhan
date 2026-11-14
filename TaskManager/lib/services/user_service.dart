import '../models/user.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient();

  // Tìm theo tên hoặc email (tối thiểu 2 ký tự, không phân biệt dấu)
  Future<List<User>> search(String query) async {
    final data = await _api.get('/users/search', query: {'q': query});
    final list = (data['users'] as List?) ?? [];
    return list.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
  }
}
