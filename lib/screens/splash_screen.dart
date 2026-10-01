import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// constants
import '../constants.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';

// Lab Activity 4 - Enhancement 1: splash UI that gates the app on persistent authentication —
// UserService.isLoggedIn() checks SharedPreferences for a saved session
// before deciding whether to land on /home or /signin.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 5000));

    // Lab Activity 5 - Enhancement 2: Keeps both Firebase and DummyJSON users logged in.
    final loggedIn = await _userService.isLoggedIn();

    if (!mounted) return;

    if (loggedIn) {
      final userData = await _userService.getUserData();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: userData);
    } else {
      Navigator.pushReplacementNamed(context, '/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/nubdexchange_logo.png', width: 96.w),
            SizedBox(height: 16.h),
            CustomText(
              text: 'NUBD Exchange',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: 28.w,
              height: 28.w,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
