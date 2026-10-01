import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'product_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

import '../services/user_service.dart';
import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  String _profileName = 'Profile';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileName();
  }

  Future<void> _loadProfileName() async {
    final firebaseUser = UserService().currentUser;
    if (firebaseUser != null &&
        (firebaseUser.displayName?.isNotEmpty ?? false)) {
      if (!mounted) return;
      setState(() {
        _profileName = firebaseUser.displayName!;
      });
      return;
    }
    final user = await UserService().getUser();
    if (!mounted || user.firstName.isEmpty) return;
    setState(() {
      _profileName = user.firstName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_selectedIndex) {
      1 => 'Chats',
      2 => 'Cart',
      3 => _profileName,
      _ => '',
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 20.w,
          title: (_selectedIndex == 0)
              ? Image.asset('assets/images/nubdexchange_logo.png', scale: 11.sp)
              : CustomText(
                  text: title,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          children: <Widget>[
            const ProductScreen(),
            _buildChatTab(),
            const CartScreen(),
            const ProfileScreen(),
          ],
          onPageChanged: (page) {
            setState(() {
              _selectedIndex = page;
            });
          },
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBar(
            height: 76.h,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onTappedBar,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shop_2_outlined),
                selectedIcon: Icon(Icons.shop_2),
                label: 'Shop',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                selectedIcon: Icon(Icons.chat),
                label: 'Chats',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    if (UserService().currentUser == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 12.h),
              CustomText(
                text: 'Chat requires a Firebase account',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              CustomText(
                text: 'Sign in with Firebase to view users and send messages.',
                fontSize: 13.sp,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return const ChatScreen();
  }

  void _onTappedBar(int value) {
    setState(() {
      _selectedIndex = value;
    });
    _pageController.jumpToPage(value);
  }
}
