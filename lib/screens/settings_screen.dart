import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// providers
import '../providers/theme_provider.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';

// Lab Activity 5 - Enhancement 3: Settings with logout redirect to login.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final loginType = prefs.getString('loginType') ?? 'dummyjson';
    final userService = UserService();

    if (loginType == 'firebase') {
      await userService.signOut();
    }
    await userService.logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        children: [
          SwitchListTile(
            secondary: Icon(
              themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
            ),
            title: CustomText(
              text: 'Dark Mode',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            subtitle: CustomText(
              text: themeProvider.isDark ? 'Currently on' : 'Currently off',
              fontSize: 12.sp,
            ),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          // Lab Activity 5 - Enhancement 3: Logout button.
          ListTile(
            leading: Icon(Icons.logout, color: Colors.deepOrange.shade300),
            title: CustomText(
              text: 'Log Out',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange.shade300,
            ),
            subtitle: CustomText(
              text: 'Sign out and return to login',
              fontSize: 12.sp,
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
