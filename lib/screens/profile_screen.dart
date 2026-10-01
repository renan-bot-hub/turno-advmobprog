import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';
import '../utils/error_message.dart';

// Lab Activity 5 - Enhancement 3: Profile with LoginType-based data display,
// update username, change password, delete account, and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  // Lab Activity 5 - Enhancement 3: UserService().getUserData() returns the
  // Firebase or DummyJSON user depending on the saved loginType.
  Future<Map<String, dynamic>> _loadProfile() => _userService.getUserData();

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  // Lab Activity 5 - Enhancement 1: Logout button clears the session and goes back to login.
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final loginType = prefs.getString('loginType') ?? 'dummyjson';

    if (loginType == 'firebase') {
      await _userService.signOut();
    }
    await _userService.logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  // Lab Activity 5 - Enhancement 3: Update username dialog.
  void _showUpdateUsernameDialog(Map<String, dynamic> profile) {
    final controller = TextEditingController(text: profile['username'] ?? '');
    final loginType = profile['loginType'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUsername = controller.text.trim();
              if (newUsername.isEmpty) return;

              try {
                if (loginType == 'firebase') {
                  await _userService.updateUsername(username: newUsername);
                } else {
                  // Update locally in SharedPreferences for DummyJSON
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('username', newUsername);
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _refreshProfile();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username updated!')),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Lab Activity 5 - Enhancement 3: Change password dialog (Firebase only).
  void _showChangePasswordDialog(Map<String, dynamic> profile) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentPwController.text.isEmpty ||
                  newPwController.text.isEmpty) {
                return;
              }
              if (newPwController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New password must be at least 6 characters'),
                  ),
                );
                return;
              }

              try {
                await _userService.resetPasswordFromCurrentPassword(
                  currentPassword: currentPwController.text,
                  newPassword: newPwController.text,
                  email: profile['email'] ?? '',
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed!')),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // Lab Activity 5 - Enhancement 3: Delete account confirmation dialog.
  void _showDeleteAccountDialog(Map<String, dynamic> profile) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action cannot be undone. Enter your password to confirm.',
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (passwordController.text.isEmpty) return;

              try {
                await _userService.deleteAccount(
                  email: profile['email'] ?? '',
                  password: passwordController.text,
                );
                await _userService.logout();

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/signin',
                  (route) => false,
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Center(
            child: CustomText(text: 'Not signed in.', fontSize: 14.sp),
          );
        }

        // Lab Activity 5 - Enhancement 3: Shows different details depending on the loginType.
        final loginType = profile['loginType'] ?? 'dummyjson';
        final isFirebase = loginType == 'firebase';
        final fullName =
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
        final displayName = (isFirebase && fullName.isEmpty)
            ? (profile['username'] ?? '')
            : fullName;
        final username = profile['username'] ?? '';
        final email = profile['email'] ?? '';
        final imageUrl = profile['image'] ?? '';
        final accountDetails = _accountDetails(profile, isFirebase);

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                // Profile card
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.h),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50.r,
                              backgroundColor: Colors.grey.shade200,
                              child: ClipOval(
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 100.r,
                                        height: 100.r,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              );
                                            },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(Icons.person, size: 50.sp),
                                      )
                                    : Icon(Icons.person, size: 50.sp),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            CustomText(
                              text: displayName.isNotEmpty
                                  ? displayName
                                  : 'User',
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            SizedBox(height: 5.h),
                            CustomText(
                              text: username.isNotEmpty ? '@$username' : email,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: isFirebase
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: CustomText(
                                text: isFirebase ? 'Firebase' : 'DummyJSON',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: isFirebase
                                    ? Colors.orange.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                Align(
                  alignment: Alignment.centerLeft,
                  child: CustomText(
                    text: 'Account details',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Card(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < accountDetails.length;
                        index++
                      ) ...[
                        _buildInfoRow(
                          accountDetails[index].icon,
                          accountDetails[index].label,
                          accountDetails[index].value,
                        ),
                        if (index < accountDetails.length - 1)
                          Divider(
                            height: 1,
                            indent: 16.w,
                            endIndent: 16.w,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                      ],
                      if (accountDetails.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(16.r),
                          child: CustomText(
                            text: 'No additional account details available.',
                            fontSize: 13.sp,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Action buttons card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: CustomText(
                          text: 'Update Username',
                          fontSize: 14.sp,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showUpdateUsernameDialog(profile),
                      ),
                      if (isFirebase) ...[
                        Divider(
                          height: 1,
                          indent: 16.w,
                          color: Colors.grey.shade300,
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: CustomText(
                            text: 'Change Password',
                            fontSize: 14.sp,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showChangePasswordDialog(profile),
                        ),
                        Divider(
                          height: 1,
                          indent: 16.w,
                          color: Colors.grey.shade300,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: CustomText(
                            text: 'Delete Account',
                            fontSize: 14.sp,
                            color: Colors.red,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDeleteAccountDialog(profile),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    onPressed: () => _logout(context),
                    icon: Icon(Icons.logout, size: 18.sp),
                    label: CustomText(
                      text: 'Log Out',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(
              icon,
              size: 18.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  text: value,
                  fontSize: 13.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<({IconData icon, String label, String value})> _accountDetails(
    Map<String, dynamic> profile,
    bool isFirebase,
  ) {
    final details = <({IconData icon, String label, String value})>[];
    void add(IconData icon, String label, dynamic value) {
      final formatted = _formatDetailValue(value);
      if (formatted.isNotEmpty) {
        details.add((icon: icon, label: label, value: formatted));
      }
    }

    add(
      Icons.badge_outlined,
      'Account ID',
      isFirebase ? profile['uid'] : profile['id'],
    );
    add(Icons.person_outline, 'First name', profile['firstName']);
    add(Icons.person_outline, 'Last name', profile['lastName']);
    add(Icons.alternate_email, 'Username', profile['username']);
    add(Icons.email_outlined, 'Email', profile['email']);
    add(
      Icons.phone_outlined,
      'Phone',
      profile['phone'] ?? profile['contactNo'],
    );
    add(Icons.cake_outlined, 'Age', profile['age']);
    add(Icons.wc_outlined, 'Gender', profile['gender']);

    if (isFirebase) {
      add(
        Icons.verified_user_outlined,
        'Email verification',
        profile['emailVerified'] == true ? 'Verified' : 'Not verified',
      );
      add(Icons.login_outlined, 'Sign-in provider', profile['signInProvider']);
      add(
        Icons.calendar_today_outlined,
        'Account created',
        profile['createdAt'],
      );
      add(Icons.history, 'Last sign-in', profile['lastSignInAt']);
    } else {
      add(Icons.badge_outlined, 'Maiden name', profile['maidenName']);
      add(Icons.event_outlined, 'Birth date', profile['birthDate']);
      add(Icons.bloodtype_outlined, 'Blood group', profile['bloodGroup']);
      add(Icons.height, 'Height', _withUnit(profile['height'], 'cm'));
      add(
        Icons.monitor_weight_outlined,
        'Weight',
        _withUnit(profile['weight'], 'kg'),
      );
      add(Icons.remove_red_eye_outlined, 'Eye color', profile['eyeColor']);
      add(Icons.face_outlined, 'Hair', profile['hair']);
      add(Icons.location_on_outlined, 'Address', profile['address']);
      add(Icons.school_outlined, 'University', profile['university']);
      add(Icons.work_outline, 'Company', profile['company']);
      add(Icons.work_history_outlined, 'Role', profile['role']);
    }

    return details;
  }

  String _withUnit(dynamic value, String unit) {
    final formatted = _formatDetailValue(value);
    return formatted.isEmpty ? '' : '$formatted $unit';
  }

  String _formatDetailValue(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value is! Map && entry.value is! List)
          .map(
            (entry) =>
                '${entry.key.toString().replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}').toLowerCase()}: ${entry.value}',
          )
          .join(' · ');
    }
    if (value is List) return value.join(', ');
    return value.toString().trim();
  }
}
