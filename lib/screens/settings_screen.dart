import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

// Enhancement 3: Add settings page to move the dark/light mode switch.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeProvider.isDark,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
    );
  }
}
