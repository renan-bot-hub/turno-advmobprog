import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

// constants
import '../constants.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';
import '../utils/error_message.dart';

// Lab Activity 5 - Enhancement 2: Sign-in supports DummyJSON and Firebase Auth.
enum _LoginProvider { dummyJson, firebase }

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  _LoginProvider _loginProvider = _LoginProvider.dummyJson;

  bool get _firebaseAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Lab Activity 6: Ignore stray spaces/quotes around the username or email.
    final identifier = _identifierController.text.trim().replaceAll(
      RegExp(r'''^["']+|["']+$'''),
      '',
    );
    final password = _passwordController.text;
    final isFirebase = _loginProvider == _LoginProvider.firebase;

    if (isFirebase && !_firebaseAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase sign-in is configured for Android only.'),
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userService = UserService();

      if (isFirebase) {
        // Lab Activity 5 - Enhancement 2: Firebase sign in, then refresh the token.
        await userService.signIn(email: identifier, password: password);
        await prefs.setString('loginType', 'firebase');
        await userService.getToken(forceRefresh: true);
        // Lab Activity 6 - Enhancement 1: Make sure the user is in the chat list.
        await userService.trySaveUserToFirestore();

        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Lab Activity 5 - Enhancement 2: DummyJSON sign in through /auth/login.
        // loginUser already saves the response to SharedPreferences.
        final response = await userService.loginUser(identifier, password);
        await prefs.setString('loginType', 'dummyjson');

        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/home', arguments: response);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/nubdexchange_logo.png',
                            width: 32.w,
                          ),
                          SizedBox(width: 8.w),
                          CustomText(
                            text: 'Welcome',
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      SizedBox(height: 32.h),
                      SegmentedButton<_LoginProvider>(
                        segments: [
                          ButtonSegment(
                            value: _LoginProvider.dummyJson,
                            label: const Text('DummyJSON'),
                          ),
                          ButtonSegment(
                            value: _LoginProvider.firebase,
                            label: const Text('Firebase'),
                            enabled: _firebaseAvailable,
                          ),
                        ],
                        selected: {_loginProvider},
                        onSelectionChanged: (selection) {
                          setState(() => _loginProvider = selection.first);
                          _identifierController.clear();
                        },
                      ),
                      if (!_firebaseAvailable) ...[
                        SizedBox(height: 8.h),
                        CustomText(
                          text:
                              'Firebase sign-in is configured for Android only.',
                          fontSize: 11.sp,
                          textAlign: TextAlign.center,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                      SizedBox(height: 20.h),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: _loginProvider == _LoginProvider.firebase
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        decoration: _fieldDecoration(
                          _loginProvider == _LoginProvider.firebase
                              ? 'Email Address'
                              : 'Username',
                        ),
                        validator: (value) {
                          final identifier = (value ?? '').trim();
                          if (identifier.isEmpty) {
                            return _loginProvider == _LoginProvider.firebase
                                ? 'Email is required'
                                : 'Username is required';
                          }
                          if (_loginProvider == _LoginProvider.firebase &&
                              !RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              ).hasMatch(identifier)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _fieldDecoration('Password'),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : CustomText(
                                    text: 'Log In',
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // Lab Activity 5 - Enhancement 2: Link to sign-up screen.
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          CustomText(
                            text: "Don't have an account? ",
                            fontSize: 13.sp,
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/signup'),
                            child: CustomText(
                              text: 'Sign Up',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: brandNavy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
