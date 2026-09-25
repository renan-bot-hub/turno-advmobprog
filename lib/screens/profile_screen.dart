import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  late final Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _userService.getUserData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) {
          return const Center(child: Text('No saved user found'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Enhancement 3: Render saved user data on the profile screen.
            CircleAvatar(
              radius: 48,
              backgroundImage: user.image.isEmpty ? null : NetworkImage(user.image),
              child: user.image.isEmpty ? const Icon(Icons.person, size: 48) : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${user.firstName} ${user.lastName}'.trim(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(leading: const Icon(Icons.email), title: Text(user.email)),
            ListTile(leading: const Icon(Icons.person), title: Text(user.username)),
            ListTile(leading: const Icon(Icons.badge), title: Text('User ID: ${user.id}')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await _userService.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/signin');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        );
      },
    );
  }
}
