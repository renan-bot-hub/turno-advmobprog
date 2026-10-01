import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/user.dart' as app_user;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

ValueNotifier<UserService> userService = ValueNotifier(UserService());

class UserService {
  Map<String, dynamic> data = {};
  static const _dummyJsonProfileFields = [
    'maidenName',
    'age',
    'birthDate',
    'phone',
    'bloodGroup',
    'height',
    'weight',
    'eyeColor',
    'hair',
    'address',
    'university',
    'company',
    'role',
  ];

  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    final response = await http
        .post(
          Uri.parse('$host/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            'expiresInMins': 60,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      data = jsonDecode(response.body);
      await saveUserData(data);
      return data;
    } else {
      throw Exception(response.body);
    }
  }

  // Lab Activity 5 - Enhancement 2: DummyJSON sign up through /users/add (simulated only).
  /// Register a user on DummyJSON (simulated — DummyJSON does not persist it)
  Future<Map<String, dynamic>> addUser(Map<String, dynamic> userData) async {
    final response = await http
        .post(
          Uri.parse('$host/users/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }

  /// Save user data from API response based on User model
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = app_user.User.fromJson(userData);

    await prefs.setInt('id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('email', user.email);
    await prefs.setString('firstName', user.firstName);
    await prefs.setString('lastName', user.lastName);
    await prefs.setString('gender', user.gender);
    await prefs.setString('image', user.image);
    await prefs.setString('accessToken', user.accessToken);
    await prefs.setString('refreshToken', user.refreshToken);
    final profileData = _safeDummyJsonProfile(userData);
    await prefs.setString('profileData', jsonEncode(profileData));

    // Support generic token key if present in API response
    if (userData.containsKey('token')) {
      await prefs.setString('token', userData['token'] ?? '');
    } else if (user.accessToken.isNotEmpty) {
      await prefs.setString('token', user.accessToken);
    }
  }

  // Lab Activity 5 - Enhancement 3: Returns Firebase or DummyJSON user data depending on the loginType.
  /// Retrieve user data based on the saved loginType:
  /// Firebase reads the signed-in FirebaseAuth user (plus signup details saved
  /// locally), DummyJSON reads the login response saved in SharedPreferences.
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final loginType = prefs.getString('loginType') ?? 'dummyjson';

    if (loginType == 'firebase') {
      final user = currentUser;
      return {
        'loginType': 'firebase',
        'id': 0,
        'uid': user?.uid ?? '',
        'username': user?.displayName ?? prefs.getString('username') ?? '',
        'email': user?.email ?? prefs.getString('email') ?? '',
        'firstName': prefs.getString('firstName') ?? '',
        'lastName': prefs.getString('lastName') ?? '',
        'age': prefs.getString('age') ?? '',
        'contactNo': prefs.getString('contactNo') ?? '',
        'phone': user?.phoneNumber ?? prefs.getString('contactNo') ?? '',
        'gender': '',
        'image': user?.photoURL ?? '',
        'emailVerified': user?.emailVerified ?? false,
        'signInProvider':
            user?.providerData
                .map((provider) => provider.providerId)
                .join(', ') ??
            '',
        'createdAt': user?.metadata.creationTime?.toIso8601String() ?? '',
        'lastSignInAt': user?.metadata.lastSignInTime?.toIso8601String() ?? '',
        'accessToken': '',
        'refreshToken': '',
        'token': prefs.getString('token') ?? '',
      };
    }

    Map<String, dynamic> savedProfile = {};
    final savedProfileJson = prefs.getString('profileData');
    if (savedProfileJson != null) {
      try {
        final decoded = jsonDecode(savedProfileJson);
        if (decoded is Map) {
          savedProfile = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        savedProfile = {};
      }
    }
    final userId = prefs.getInt('id') ?? 0;
    if (savedProfile.isEmpty && userId > 0) {
      try {
        final response = await http
            .get(Uri.parse('$host/users/$userId'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          savedProfile = _safeDummyJsonProfile(jsonDecode(response.body));
          await prefs.setString('profileData', jsonEncode(savedProfile));
        }
      } catch (_) {
        // Existing saved details remain available when the API is offline.
      }
    }

    return {
      ...savedProfile,
      'loginType': 'dummyjson',
      'id': userId,
      'username': prefs.getString('username') ?? '',
      'email': prefs.getString('email') ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'gender': prefs.getString('gender') ?? '',
      'image': prefs.getString('image') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
      'refreshToken': prefs.getString('refreshToken') ?? '',
      'token': prefs.getString('token') ?? prefs.getString('accessToken') ?? '',
    };
  }

  Map<String, dynamic> _safeDummyJsonProfile(dynamic userData) {
    if (userData is! Map) return {};
    return {
      for (final field in _dummyJsonProfileFields)
        if (userData[field] != null) field: userData[field],
    };
  }

  /// Retrieve User model from SharedPreferences
  Future<app_user.User> getUser() async {
    final userData = await getUserData();
    return app_user.User.fromJson(userData);
  }

  // Lab Activity 5 - Enhancement 2: Checks both the Firebase session and the DummyJSON token.
  /// Check if a user is currently logged in (Firebase session or DummyJSON token)
  Future<bool> isLoggedIn() async {
    try {
      final firebaseUser = await firebaseAuth.authStateChanges().first;
      if (firebaseUser != null) return true;
    } on FirebaseException {
      // Targets without Firebase options can still use DummyJSON accounts.
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  // Lab Activity 5 - Enhancement 1: Logout clears the saved session and token.
  /// Logout and clear stored user data
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to log out: $e');
    }
  }

  // Lab Activity 5 - Enhancement 1: Firebase Auth methods for user management.
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  User? get currentUser {
    try {
      return firebaseAuth.currentUser;
    } on FirebaseException {
      return null;
    }
  }

  // Lab Activity 6: Throws a readable error instead of crashing on a null
  // user when the session has expired.
  User get _signedInUser =>
      currentUser ??
      (throw Exception('You are not logged in. Please log in again.'));

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  // Lab Activity 5 - Enhancement 2: Firebase token refresh.
  /// Get the Firebase ID token; forceRefresh fetches a fresh one from Firebase
  /// instead of using the cached token, and saves it like the DummyJSON token.
  Future<String?> getToken({bool forceRefresh = false}) async {
    final token = await currentUser?.getIdToken(forceRefresh);
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
    }
    return token;
  }

  // Lab Activity 5 - Enhancement 1: Signs in with email and password using Firebase.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Lab Activity 5 - Enhancement 1: Creates a new Firebase account.
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Lab Activity 6 - Enhancement 1: Saves the signed-in Firebase user to the
  // Firestore `Users` collection so they appear in the chat list.
  Future<void> saveUserToFirestore({
    String? firstName,
    String? lastName,
    String? username,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final doc = FirebaseFirestore.instance.collection('Users').doc(user.uid);
    final existing = (await doc.get()).data() ?? {};
    final data = <String, dynamic>{'uid': user.uid, 'email': user.email ?? ''};

    if (firstName != null && firstName.isNotEmpty) {
      data['firstName'] = firstName;
    } else if ((existing['firstName'] ?? '').toString().isEmpty) {
      // Accounts made before Lab Activity 6 have no Users doc yet.
      data['firstName'] = (user.displayName?.isNotEmpty ?? false)
          ? user.displayName
          : (user.email ?? '').split('@').first;
    }
    if (lastName != null && lastName.isNotEmpty) data['lastName'] = lastName;
    if (username != null && username.isNotEmpty) data['username'] = username;

    await doc.set(data, SetOptions(merge: true));
  }

  // Lab Activity 6 - Enhancement 1: Same as saveUserToFirestore, but a
  // Firestore problem (e.g. security rules) won't stop sign-up or login.
  // The user is saved again on their next login.
  Future<void> trySaveUserToFirestore({
    String? firstName,
    String? lastName,
    String? username,
  }) async {
    try {
      await saveUserToFirestore(
        firstName: firstName,
        lastName: lastName,
        username: username,
      );
    } catch (e) {
      debugPrint('Could not save user to Firestore: $e');
    }
  }

  // Lab Activity 5 - Enhancement 1: Signs out the Firebase user.
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  // Lab Activity 5 - Enhancement 1: Updates the Firebase display name (username).
  Future<void> updateUsername({required String username}) async {
    await _signedInUser.updateDisplayName(username);
  }

  // Lab Activity 5 - Enhancement 1: Re-checks the password, then deletes the Firebase account.
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await _signedInUser.reauthenticateWithCredential(credential);
    await _signedInUser.delete();
    await firebaseAuth.signOut();
  }

  // Lab Activity 5 - Enhancement 1: Re-checks the current password, then sets a new one.
  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await _signedInUser.reauthenticateWithCredential(credential);
    await _signedInUser.updatePassword(newPassword);
  }
}
