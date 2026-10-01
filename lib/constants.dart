import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get host => dotenv.env['HOST'] ?? 'https://dummyjson.com';

// Shared brand colors for app surfaces and primary actions.
const brandNavy = Color(0xFF263A5A);
const brandGold = Color(0xFFC5A66A);
