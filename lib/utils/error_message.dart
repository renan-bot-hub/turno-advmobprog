import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _fallback = 'Something went wrong. Please try again.';

// Lab Activity 6: Turns any error (Firebase, network, DummyJSON) into a short,
// user-friendly message instead of showing raw codes like
// "[firebase_auth/...]" or "Exception: ...".
String errorMessage(Object? error) {
  if (error is FirebaseAuthException) return _authMessage(error);
  if (error is FirebaseException) return _firestoreMessage(error);

  if (error is SocketException || error is http.ClientException) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (error is TimeoutException) {
    return 'The server took too long to respond. Please try again.';
  }
  if (error is FormatException) {
    return 'The server sent an unexpected response. Please try again.';
  }

  // Our services throw Exception('<message>'), and DummyJSON errors are
  // thrown as Exception(<response body>) e.g. {"message":"Invalid credentials"}.
  final text = (error ?? '').toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty) return _fallback;
  try {
    final body = jsonDecode(text);
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
  } catch (_) {}
  return text;
}

String _authMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'requires-recent-login':
      return 'For your security, please log out and log in again first.';
    case 'user-mismatch':
      return 'That password belongs to a different account.';
    case 'operation-not-allowed':
      return 'Email sign-in is not enabled for this app.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network and try again.';
  }
  return error.message ?? _fallback;
}

String _firestoreMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return "You don't have permission to do that. Please log in again.";
    case 'unauthenticated':
      return 'Your session has expired. Please log in again.';
    case 'unavailable':
    case 'deadline-exceeded':
      return "Can't reach the server. Please check your internet connection.";
    case 'not-found':
      return 'That item no longer exists.';
    case 'resource-exhausted':
      return 'Too many requests. Please try again later.';
  }
  return error.message ?? _fallback;
}
