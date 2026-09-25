import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/user.dart';

class UserService {
	Future<User> login(String username, String password) async {
		final response = await http.post(
			Uri.parse('$host/auth/login'),
			headers: {'Content-Type': 'application/json'},
			body: jsonEncode({
				'username': username,
				'password': password,
				'expiresInMins': 30,
			}),
		);

		if (response.statusCode == 200) {
			return User.fromJson(jsonDecode(response.body));
		}

		throw Exception('Failed to login');
	}

	Future<bool> saveUserData(User user) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setInt('user.id', user.id);
		await prefs.setString('user.username', user.username);
		await prefs.setString('user.password', user.password);
		await prefs.setString('user.firstName', user.firstName);
		await prefs.setString('user.lastName', user.lastName);
		await prefs.setString('user.email', user.email);
		await prefs.setString('user.image', user.image);
		await prefs.setString('user.gender', user.gender);
		await prefs.setString('user.accessToken', user.accessToken);
		await prefs.setString('user.refreshToken', user.refreshToken);

		return _saveToken(prefs, user.accessToken, user.refreshToken);
	}

	Future<User?> getUserData() async {
		final prefs = await SharedPreferences.getInstance();
		final id = prefs.getInt('user.id');

		if (id == null) {
			return null;
		}

		return User(
			id: id,
			username: prefs.getString('user.username') ?? '',
			password: prefs.getString('user.password') ?? '',
			firstName: prefs.getString('user.firstName') ?? '',
			lastName: prefs.getString('user.lastName') ?? '',
			email: prefs.getString('user.email') ?? '',
			image: prefs.getString('user.image') ?? '',
			gender: prefs.getString('user.gender') ?? '',
			accessToken: prefs.getString('user.accessToken') ?? '',
			refreshToken: prefs.getString('user.refreshToken') ?? '',
		);
	}

	Future<User?> getSavedUser() => getUserData();

	Future<bool> isLoggedIn() async {
		final prefs = await SharedPreferences.getInstance();
		final token = prefs.getString('user.accessToken');
		return token != null && token.isNotEmpty;
	}

	Future<void> logout() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.clear();
	}

	bool _saveToken(
		SharedPreferences prefs,
		String accessToken,
		String refreshToken,
	) {
		if (accessToken.isNotEmpty) {
			prefs.setString('user.accessToken', accessToken);
		}
		if (refreshToken.isNotEmpty) {
			prefs.setString('user.refreshToken', refreshToken);
		}
		return true;
	}
}
