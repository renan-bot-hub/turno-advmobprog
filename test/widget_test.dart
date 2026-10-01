// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turno_advmobprog/main.dart';
import 'package:turno_advmobprog/screens/home_screen.dart';
import 'package:turno_advmobprog/screens/profile_screen.dart';
import 'package:turno_advmobprog/screens/signin_screen.dart';
import 'package:turno_advmobprog/services/currency_service.dart';

void main() {
  test('USD prices convert and format as Philippine pesos', () {
    expect(CurrencyService.formatUsdAsPhp(10, 57.25), '₱572.50');
  });

  testWidgets('splash opens sign-in when no session is saved', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SungaAdvMobProg());
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('sign-in form validates required credentials', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(412, 715),
        builder: (context, child) => const MaterialApp(home: SigninScreen()),
      ),
    );

    expect(find.text('DummyJSON'), findsOneWidget);
    expect(find.text('Firebase'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);

    if (find.text('Firebase').evaluate().isNotEmpty) {
      await tester.tap(find.text('Firebase'));
      await tester.pumpAndSettle();
      expect(find.text('Email Address'), findsOneWidget);
      await tester.tap(find.text('DummyJSON'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('sign-in form scrolls without overflowing a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(412, 715),
        builder: (context, child) => const MaterialApp(home: SigninScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Log In'));
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat is the second tab and prompts without a Firebase user', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(412, 715),
        builder: (context, child) => const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Chats'));
    await tester.pump();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Chat requires a Firebase account'), findsOneWidget);
  });

  testWidgets('profile shows the saved account details', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'loginType': 'dummyjson',
      'id': 42,
      'username': 'mika.tan',
      'email': 'mika.tan.with.a.long.account.name@example.com',
      'firstName': 'Mika',
      'lastName': 'Tan',
      'gender': 'female',
      'profileData': jsonEncode({
        'age': 22,
        'phone': '+63 912 345 6789',
        'birthDate': '2004-05-20',
        'university': 'National University',
        'role': 'student',
        'address': {
          'street': '123 A Very Long University Avenue Extension',
          'city': 'Manila',
          'country': 'Philippines',
        },
      }),
    });

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(412, 715),
        builder: (context, child) => const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Account ID'), findsOneWidget);
    expect(
      find.text('mika.tan.with.a.long.account.name@example.com'),
      findsOneWidget,
    );
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('+63 912 345 6789'), findsOneWidget);
    expect(find.text('National University'), findsOneWidget);
    expect(find.textContaining('Manila'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
