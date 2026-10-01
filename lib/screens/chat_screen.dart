import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/error_message.dart';
import '../widgets/custom_text.dart';
import 'chat_detailscreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchChatController = TextEditingController();
  final ChatService _chatService = ChatService();
  String? _currentUserEmail;
  String _searchText = '';
  // Lab Activity 6: created once (not in build) so typing in the search bar
  // doesn't restart the Firestore query; replaced when the user taps Retry.
  late Stream<List<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _chatService.getUsersStream();
    _loadCurrentUserEmail();
  }

  Future<void> _loadCurrentUserEmail() async {
    try {
      final userData = await userService.value.getUserData();
      if (!mounted) return;
      setState(() {
        _currentUserEmail = userData['email'];
      });
    } catch (e) {
      // The current user is still hidden from the list by their Firebase UID.
      debugPrint('Could not load current user email: $e');
    }
  }

  @override
  void dispose() {
    _searchChatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lab Activity 6 - Enhancement 2: the search bar stays pinned at the top
    // while the user list below it scrolls.
    return Column(
      children: [
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 23.w),
          child: TextField(
            controller: _searchChatController,
            textInputAction: TextInputAction.search,
            // Lab Activity 6 - Enhancement 2: Update the results while typing.
            onChanged: (value) {
              setState(() {
                _searchText = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search chat...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: (_searchChatController.text.isNotEmpty)
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        setState(() {
                          _searchChatController.clear();
                          _searchText = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),

        // Users Stream
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: EdgeInsets.all(16.sp),
                  child: const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                );
              }
              // Lab Activity 6: readable error with a Retry button.
              if (snapshot.hasError) {
                return Container(
                  padding: EdgeInsets.all(16.sp),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          text: errorMessage(snapshot.error),
                          fontSize: 16.sp,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _usersStream = _chatService.getUsersStream();
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16.sp),
                  child: Center(
                    child: CustomText(text: 'No users found', fontSize: 16.sp),
                  ),
                );
              }

              // Lab Activity 6 - Enhancement 1: every registered user except
              // the one currently logged in (matched by Firebase UID).
              final currentUid = userService.value.currentUser?.uid;
              final currentEmail = (_currentUserEmail ?? '').toLowerCase();
              final users = snapshot.data!.where((user) {
                if (user['uid'] == currentUid) return false;
                final email = (user['email'] ?? '').toString().toLowerCase();
                if (currentEmail.isNotEmpty && email == currentEmail) {
                  return false;
                }

                // Lab Activity 6 - Enhancement 2: filter by name or email.
                if (_searchText.isEmpty) return true;
                final name = [
                  user['firstName'],
                  user['lastName'],
                  user['username'],
                ].where((v) => v != null).join(' ').toLowerCase();
                return name.contains(_searchText) ||
                    email.contains(_searchText);
              }).toList();
              users.sort(
                (a, b) => (a['firstName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo((b['firstName'] ?? '').toString().toLowerCase()),
              );

              if (users.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16.sp),
                  child: Center(
                    child: CustomText(
                      // Lab Activity 6 - Enhancement 2: Message when the search has no match.
                      text: _searchText.isEmpty
                          ? 'No other users yet'
                          : 'No users match "${_searchChatController.text.trim()}"',
                      fontSize: 16.sp,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return GestureDetector(
                    onTap: () {
                      // Lab Activity 6: a Users doc without a uid can't be chatted with.
                      if ((user['uid'] ?? '').toString().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Can't open a chat with this user."),
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            currentUserEmail: _currentUserEmail ?? '',
                            tappedUser: user,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      child: ListTile(
                        // Lab Activity 6 - Enhancement 3: Hero avatar animates into the chat detail header.
                        leading: Hero(
                          tag: 'chat_avatar_${user['uid']}',
                          child: CircleAvatar(
                            child: CustomText(
                              text:
                                  user['firstName'] != null &&
                                      user['firstName'].toString().isNotEmpty
                                  ? user['firstName'][0].toUpperCase()
                                  : '?',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: CustomText(
                          text: user['firstName'] ?? 'Unknown',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        subtitle: CustomText(
                          text: user['email'] ?? 'No email',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
