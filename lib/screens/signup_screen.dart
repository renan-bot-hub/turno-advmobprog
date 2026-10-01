import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

// constants
import '../constants.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';
import '../utils/error_message.dart';

// Lab Activity 5 - Enhancement 2: Signup screen with Firebase Auth.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactNoController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Lab Activity 6: Letters (including ñ and accents), spaces, hyphens and apostrophes.
  static final _namePattern = RegExp(
    r"^[a-zA-ZÀ-ÿñÑ]+([ '\-][a-zA-ZÀ-ÿñÑ]+)*$",
  );

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _ageController.dispose();
    _contactNoController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Lab Activity 5 - Enhancement 2: Creates the Firebase account and saves the signup details.
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userService = UserService();

      // Firebase Auth registration
      final credential = await userService.createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save user display name and profile info
      final displayName = _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : '${_fNameController.text.trim()} ${_lNameController.text.trim()}'
                .trim();

      await credential.user?.updateDisplayName(displayName);

      await prefs.setString('loginType', 'firebase');
      await prefs.setString('firstName', _fNameController.text.trim());
      await prefs.setString('lastName', _lNameController.text.trim());
      await prefs.setString('username', _usernameController.text.trim());
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('contactNo', _contactNoController.text.trim());
      await prefs.setString('age', _ageController.text.trim());
      await userService.getToken(forceRefresh: true);

      // Lab Activity 6 - Enhancement 1: Add the new user to the chat list.
      await userService.trySaveUserToFirestore(
        firstName: _fNameController.text.trim(),
        lastName: _lNameController.text.trim(),
        username: _usernameController.text.trim(),
      );

      // DummyJSON /users/add (simulated — see dummyjson.com/users). Non-fatal:
      // the Firebase account is already created if this request fails.
      try {
        await userService.addUser({
          'firstName': _fNameController.text.trim(),
          'lastName': _lNameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'phone': _contactNoController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
        });
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      Navigator.pushReplacementNamed(context, '/home');
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
      appBar: AppBar(
        title: CustomText(
          text: 'Create Account',
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lab Activity 6: Names accept letters only (spaces, - and ' allowed).
                // First Name
                TextFormField(
                  // Lab Activity 6: Only check a field after the user types in it.
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _fNameController,
                  decoration: _fieldDecoration('First Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.isEmpty) {
                      return 'First name is required';
                    }
                    if (name.length < 2) {
                      return 'First name must be at least 2 letters';
                    }
                    if (!_namePattern.hasMatch(name)) {
                      return 'First name can only contain letters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Last Name
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _lNameController,
                  decoration: _fieldDecoration('Last Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.isEmpty) {
                      return 'Last name is required';
                    }
                    if (name.length < 2) {
                      return 'Last name must be at least 2 letters';
                    }
                    if (!_namePattern.hasMatch(name)) {
                      return 'Last name can only contain letters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Lab Activity 6: Age must be a whole number from 13 to 100.
                // Age
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _ageController,
                  decoration: _fieldDecoration('Age').copyWith(counterText: ''),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Age is required';
                    }
                    final age = int.tryParse(value);
                    if (age == null) {
                      return 'Enter a valid number';
                    }
                    if (age < 13 || age > 100) {
                      return 'Age must be between 13 and 100';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Contact Number
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _contactNoController,
                  decoration: _fieldDecoration('Contact Number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Contact number is required'
                      : null,
                ),
                SizedBox(height: 12.h),

                // Lab Activity 6: Username is 4-20 letters, numbers, _ or .
                // and must start with a letter.
                // Username
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _usernameController,
                  decoration: _fieldDecoration('Username'),
                  autocorrect: false,
                  validator: (value) {
                    final username = (value ?? '').trim();
                    if (username.isEmpty) {
                      return 'Username is required';
                    }
                    if (username.length < 4 || username.length > 20) {
                      return 'Username must be 4 to 20 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) {
                      return 'Username must start with a letter';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(username)) {
                      return 'Use only letters, numbers, _ or .';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Lab Activity 6: Email must be a valid email address.
                // Email Address
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _emailController,
                  decoration: _fieldDecoration(
                    'Email Address',
                  ).copyWith(hintText: 'name@example.com'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      caseSensitive: false,
                    ).hasMatch(email)) {
                      return 'Enter a valid email (e.g. name@example.com)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                // Lab Activity 5 - Enhancement 2: Password validation (required, at least 6 characters).
                // Password (min 6 characters)
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _fieldDecoration('Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24.h),

                // Register button
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
                    onPressed: _isLoading ? null : _register,
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
                              text: 'Sign Up',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Back to sign-in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomText(
                      text: 'Already have an account? ',
                      fontSize: 13.sp,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: CustomText(
                        text: 'Log In',
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
    );
  }
}
