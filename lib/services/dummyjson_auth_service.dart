import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/user.dart';

class DummyJsonAuthService {
  Future<User> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$host/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return User.fromJson(data);
    }

    throw Exception(data['message'] ?? 'DummyJSON sign-in failed.');
  }
}
