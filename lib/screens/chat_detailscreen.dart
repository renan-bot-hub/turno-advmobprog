import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:turno_advmobprog/widgets/custom_text.dart';

import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/error_message.dart';

final ChatService chatService = ChatService();

// Lab Activity 6 - Enhancement 3: sending → delivered → seen, or failed.
enum MessageStatus { sending, delivered, seen, failed }

// Lab Activity 6 - Enhancement 3: a message that could not be sent. It stays
// in the chat (marked "Not sent") so the user can retry or delete it.
class _FailedMessage {
  _FailedMessage(this.text, this.time)
    : id = 'failed_${time.microsecondsSinceEpoch}';

  final String id;
  final String text;
  final DateTime time;
}

// One row in the chat: either a Firestore message or a local failed one.
class _ChatEntry {
  const _ChatEntry({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.status,
    this.seenAt,
    this.failedMessage,
  });

  final String id;
  final String text;
  final bool isMe;
  final DateTime? time;
  final MessageStatus? status;
  final DateTime? seenAt;
  final _FailedMessage? failedMessage;
}

// Lab Activity 6 - Enhancement 3: Chat Detail Screen redesign.
class ChatDetailScreen extends StatefulWidget {
  final String currentUserEmail;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    super.key,
    required this.currentUserEmail,
    required this.tappedUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late Future<String> _currentUserIdFuture;
  // Lab Activity 6: created once (not in build) so rebuilds, e.g. typing,
  // don't restart the Firestore query; cleared when the user taps Retry.
  Stream<QuerySnapshot>? _messagesStream;
  bool _hasText = false;
  bool _markingSeen = false;

  // Lab Activity 6 - Enhancement 3: messages that failed to send.
  final List<_FailedMessage> _failed = [];

  // Lab Activity 6 - Enhancement 3: scroll-to-latest button + unread badge.
  bool _showScrollDown = false;
  int _unreadWhileAway = 0;
  String? _latestDocId;

  // Messages already on screen; only ones not in here get the entrance
  // animation, so scrolling doesn't replay it. On first load the latest
  // messages get a staggered delay instead.
  final Set<String> _shownIds = {};
  final Map<String, Duration> _initialDelays = {};
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _currentUserIdFuture = _getCurrentUserId();
    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  Future<String> _getCurrentUserId() async {
    final userData = await userService.value.getUserData();
    return (userData['uid'] ?? '').toString();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The list is reversed, so offset 0 is the latest message.
    final show = _scrollCtrl.offset > 250;
    if (show != _showScrollDown) {
      setState(() {
        _showScrollDown = show;
        if (!show) _unreadWhileAway = 0;
      });
    }
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // Lab Activity 6 - Enhancement 3: Sending state.
  // The message shows up right away as "Sending…" (Firestore pending write)
  // and flips to delivered once the server confirms it. If it fails, it stays
  // in the chat as "Not sent · Tap to retry".
  Future<void> _send(String receiverId, {_FailedMessage? retry}) async {
    final text = retry?.text ?? _msgCtrl.text.trim();
    if (text.isEmpty) return;

    if (retry != null) {
      setState(() => _failed.remove(retry));
    } else {
      _msgCtrl.clear();
      _msgFocus.requestFocus();
    }
    HapticFeedback.lightImpact();
    _scrollToLatest();

    try {
      await chatService.sendMessage(receiverId, text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed.insert(0, _FailedMessage(text, DateTime.now())));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  // Lab Activity 6 - Enhancement 3: Seen state.
  // Marks incoming messages as seen while this chat is open.
  void _markSeen(
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
    String tappedUserId,
  ) {
    if (_markingSeen) return;
    final hasUnseen = docs.any((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['receiverId'] == currentUserId && data['seen'] == false;
    });
    if (!hasUnseen) return;

    _markingSeen = true;
    chatService
        .markMessagesAsSeen(currentUserId, tappedUserId)
        .catchError((e) => debugPrint('Could not mark messages as seen: $e'))
        .whenComplete(() => _markingSeen = false);
  }

  // Counts new incoming messages while the user is scrolled up.
  void _trackNewMessages(List<QueryDocumentSnapshot> docs, String myId) {
    if (docs.isEmpty) return;
    final newest = docs.first;
    if (_latestDocId != null && newest.id != _latestDocId && _showScrollDown) {
      final data = newest.data() as Map<String, dynamic>;
      if (data['senderId'] != myId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _unreadWhileAway++);
        });
      }
    }
    _latestDocId = newest.id;
  }

  _ChatEntry _entryFromDoc(QueryDocumentSnapshot doc, String myId) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = (data['senderId'] ?? '').toString() == myId;

    // Lab Activity 6 - Enhancement 3: Sending / delivered / seen status.
    MessageStatus? status;
    if (isMe) {
      status = doc.metadata.hasPendingWrites
          ? MessageStatus.sending
          : data['seen'] == true
          ? MessageStatus.seen
          : MessageStatus.delivered;
    }

    return _ChatEntry(
      id: doc.id,
      text: (data['message'] ?? '').toString(),
      isMe: isMe,
      time: _toDate(data['timestamp']),
      status: status,
      seenAt: _toDate(data['seenAt']),
    );
  }

  // Lab Activity 6 - Enhancement 3: long-press a message for Copy (and
  // Try again / Delete when it failed to send).
  void _showMessageActions(_ChatEntry entry, String receiverId) {
    HapticFeedback.mediumImpact();
    _msgFocus.unfocus();
    final failed = entry.failedMessage;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.time != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: CustomText(
                    text: [
                      '${failed != null ? 'Tried' : 'Sent'} ${_formatFull(entry.time!)}',
                      if (entry.seenAt != null)
                        'Seen ${_formatFull(entry.seenAt!)}',
                    ].join('  ·  '),
                    fontSize: 12.sp,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: entry.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              if (failed != null) ...[
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Try again'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _send(receiverId, retry: failed);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text('Delete', style: TextStyle(color: colors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _failed.remove(failed));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
    final tappedUserName = (widget.tappedUser['firstName'] ?? '').toString();
    final tappedUserEmail = (widget.tappedUser['email'] ?? '').toString();
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<String>(
      future: _currentUserIdFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Lab Activity 6: readable errors, with an app bar so the user can go back.
        if (snap.hasError) {
          return _ChatErrorScaffold(message: errorMessage(snap.error));
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const _ChatErrorScaffold(
            message: 'Chat is only available when you log in with your email.',
          );
        }
        if (tappedUserId.isEmpty) {
          return const _ChatErrorScaffold(
            message: "Can't open a chat with this user.",
          );
        }

        final currentUserId = snap.data!;
        _messagesStream ??= chatService.getMessage(currentUserId, tappedUserId);

        return Scaffold(
          // Lab Activity 6 - Enhancement 3: Modern header with avatar, name and email.
          appBar: AppBar(
            titleSpacing: 0,
            elevation: 1,
            title: Row(
              children: [
                Hero(
                  tag: 'chat_avatar_$tappedUserId',
                  child: CircleAvatar(
                    radius: 18.r,
                    child: CustomText(
                      text: tappedUserName.isNotEmpty
                          ? tappedUserName[0].toUpperCase()
                          : '?',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: tappedUserName.isNotEmpty
                            ? tappedUserName
                            : 'Unknown',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      CustomText(
                        text: tappedUserEmail,
                        fontSize: 11.sp,
                        color: colors.onSurfaceVariant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Messages
              Expanded(
                child: Stack(
                  children: [
                    // Lab Activity 6 - Enhancement 3: subtle tinted chat background.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.surface,
                              Color.alphaBlend(
                                colors.primary.withValues(alpha: 0.06),
                                colors.surface,
                              ),
                            ],
                          ),
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _msgFocus.unfocus(),
                          child: _buildMessages(
                            currentUserId,
                            tappedUserId,
                            tappedUserName,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16.w,
                      bottom: 12.h,
                      child: _ScrollDownButton(
                        visible: _showScrollDown,
                        unread: _unreadWhileAway,
                        onTap: _scrollToLatest,
                      ),
                    ),
                  ],
                ),
              ),

              // Lab Activity 6 - Enhancement 3: Composer redesign (rounded field, animated send button).
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            focusNode: _msgFocus,
                            textInputAction: TextInputAction.send,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) => _send(tappedUserId),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.sp,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message…',
                              hintStyle: const TextStyle(fontFamily: 'Poppins'),
                              filled: true,
                              fillColor: colors.surfaceContainerHighest,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        // Grows, fills with colour and tilts up when there's text.
                        AnimatedScale(
                          scale: _hasText ? 1 : 0.85,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hasText
                                  ? colors.primary
                                  : colors.surfaceContainerHighest,
                            ),
                            child: IconButton(
                              tooltip: 'Send',
                              icon: AnimatedRotation(
                                turns: _hasText ? -0.08 : 0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: Icon(
                                  Icons.send_rounded,
                                  color: _hasText
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              onPressed: _hasText
                                  ? () => _send(tappedUserId)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(
    String currentUserId,
    String tappedUserId,
    String tappedUserName,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Lab Activity 6: readable error with a Retry button.
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomText(
                    text: errorMessage(snapshot.error),
                    fontSize: 14.sp,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _messagesStream = null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Lab Activity 6 - Enhancement 3: on first load, the latest messages
        // fade in one after another (newest first).
        if (!_initialLoadDone) {
          for (var i = 0; i < docs.length && i < 12; i++) {
            _initialDelays[docs[i].id] = Duration(milliseconds: 35 * i);
          }
          _shownIds.addAll(docs.map((d) => d.id));
          _initialLoadDone = true;
        }
        _trackNewMessages(docs, currentUserId);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _markSeen(docs, currentUserId, tappedUserId),
        );

        final entries = <_ChatEntry>[
          for (final f in _failed)
            _ChatEntry(
              id: f.id,
              text: f.text,
              isMe: true,
              time: f.time,
              status: MessageStatus.failed,
              failedMessage: f,
            ),
          for (final d in docs) _entryFromDoc(d, currentUserId),
        ];

        if (entries.isEmpty) {
          return _EmptyChat(name: tappedUserName);
        }

        // Only my latest sent message shows the Sending/Delivered/Seen line.
        final latestMineIndex = entries.indexWhere(
          (e) => e.isMe && e.status != MessageStatus.failed,
        );

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          itemCount: entries.length,
          findChildIndexCallback: (key) {
            final id = (key as ValueKey<String>).value;
            final index = entries.indexWhere((e) => e.id == id);
            return index < 0 ? null : index;
          },
          itemBuilder: (context, index) {
            final entry = entries[index];

            // Lab Activity 6 - Enhancement 3: Group messages and add date separators.
            // The list is reversed: index + 1 is the older message above,
            // index - 1 the newer one below.
            final older = index + 1 < entries.length
                ? entries[index + 1]
                : null;
            final newer = index > 0 ? entries[index - 1] : null;
            final showDate = older == null || !_sameDay(entry.time, older.time);
            final startsGroup = showDate || older.isMe != entry.isMe;
            final endsGroup = newer == null || newer.isMe != entry.isMe;

            // Lab Activity 6 - Enhancement 3: Only new messages animate in.
            Duration? entranceDelay = _initialDelays.remove(entry.id);
            if (!_shownIds.contains(entry.id)) entranceDelay = Duration.zero;
            _shownIds.add(entry.id);

            final failed = entry.failedMessage;

            return Column(
              key: ValueKey<String>(entry.id),
              children: [
                if (showDate && entry.time != null)
                  _DateChip(date: entry.time!),
                _MessageBubble(
                  entry: entry,
                  startsGroup: startsGroup,
                  endsGroup: endsGroup,
                  showStatusLine: failed != null || index == latestMineIndex,
                  entranceDelay: entranceDelay,
                  onTap: failed != null
                      ? () => _send(tappedUserId, retry: failed)
                      : null,
                  onLongPress: () => _showMessageActions(entry, tappedUserId),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

DateTime? _toDate(dynamic ts) => ts is Timestamp ? ts.toDate() : null;

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

String _formatTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _formatDay(DateTime t) {
  final now = DateTime.now();
  if (_sameDay(t, now)) return 'Today';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}, ${t.year}';
}

String _formatFull(DateTime t) => '${_formatDay(t)}, ${_formatTime(t)}';

// Lab Activity 6 - Enhancement 3: sender bubbles are a primary-colour gradient
// on the right, receiver bubbles are neutral on the left. Consecutive messages
// from the same person are grouped and only the last one gets the tail corner.
// New messages fade and slide in from their own side, and bubbles shrink
// slightly while pressed.
class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.entry,
    required this.startsGroup,
    required this.endsGroup,
    required this.showStatusLine,
    required this.entranceDelay,
    required this.onLongPress,
    this.onTap,
  });

  final _ChatEntry entry;
  final bool startsGroup;
  final bool endsGroup;
  final bool showStatusLine;
  // null = already on screen (no animation), otherwise animate after the delay.
  final Duration? entranceDelay;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.entranceDelay;
    if (delay == null) {
      _controller.value = 1;
    } else if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final isMe = entry.isMe;
    final isFailed = entry.status == MessageStatus.failed;
    final fg = isMe ? colors.onPrimary : colors.onSurface;
    const big = Radius.circular(18);
    const small = Radius.circular(4);

    final bubble = Container(
      margin: EdgeInsets.only(
        left: isMe ? 60.w : 10.w,
        right: isMe ? 10.w : 60.w,
        top: widget.startsGroup ? 8.h : 2.h,
      ),
      padding: EdgeInsets.fromLTRB(14.w, 9.h, 12.w, 6.h),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.45)!,
                ].map((c) => isFailed ? c.withValues(alpha: 0.55) : c).toList(),
              )
            : null,
        color: isMe ? null : colors.surfaceContainerHighest,
        border: isFailed ? Border.all(color: colors.error, width: 1.2) : null,
        borderRadius: BorderRadius.only(
          topLeft: isMe || widget.startsGroup ? big : small,
          topRight: !isMe || widget.startsGroup ? big : small,
          bottomLeft: isMe || !widget.endsGroup ? big : small,
          bottomRight: !isMe || !widget.endsGroup ? big : small,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: CustomText(
              text: entry.text.isNotEmpty ? entry.text : '[empty]',
              fontSize: 15.sp,
              color: fg,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.time != null)
                CustomText(
                  text: _formatTime(entry.time!),
                  fontSize: 10.sp,
                  color: fg.withValues(alpha: 0.7),
                ),
              if (entry.status != null) ...[
                SizedBox(width: 4.w),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: _StatusIcon(
                    key: ValueKey(entry.status),
                    status: entry.status!,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    // Lab Activity 6 - Enhancement 3: Fade + slide animation for new messages.
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isMe ? 0.2 : -0.2, 0.3),
          end: Offset.zero,
        ).animate(_curve),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: GestureDetector(
                  onTapDown: (_) => _setPressed(true),
                  onTapUp: (_) => _setPressed(false),
                  onTapCancel: () => _setPressed(false),
                  onTap: widget.onTap,
                  onLongPress: () {
                    _setPressed(false);
                    widget.onLongPress();
                  },
                  child: AnimatedScale(
                    scale: _pressed ? 0.96 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: bubble,
                  ),
                ),
              ),
            ),
            // Sending… → Delivered → Seen · time, or Not sent · Tap to retry.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child:
                widget.showStatusLine &&
                  entry.status != null &&
                  entry.status != MessageStatus.delivered
                  ? _StatusLine(entry: entry)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

// Lab Activity 6 - Enhancement 3: Sending state indicator inside the bubble.
// 🕓 sending, ✓ delivered, ✓✓ seen (blue), ⚠ failed.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({super.key, required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule_rounded, size: 13.sp, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_rounded, size: 15.sp, color: color);
      case MessageStatus.seen:
        return Icon(
          Icons.done_all_rounded,
          size: 15.sp,
          color: Colors.lightBlueAccent.shade100,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14.sp,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}

// Lab Activity 6 - Enhancement 3: status text under my latest message (and
// under failed ones). Changes slide/fade in place.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.entry});

  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;

    final (String text, Color color, Widget? leading) = switch (entry.status) {
      MessageStatus.sending => (
        'Sending…',
        muted,
        SizedBox(
          width: 9.sp,
          height: 9.sp,
          child: CircularProgressIndicator(strokeWidth: 1.4, color: muted),
        ),
      ),
      MessageStatus.seen => (
        entry.seenAt != null ? 'Seen · ${_formatTime(entry.seenAt!)}' : 'Seen',
        colors.primary,
        null,
      ),
      MessageStatus.failed => (
        'Not sent · Tap to retry',
        colors.error,
        Icon(Icons.error_outline_rounded, size: 12.sp, color: colors.error),
      ),
      _ => ('Delivered', muted, null),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 3.h, 14.w, 2.h),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(text),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, SizedBox(width: 4.w)],
            CustomText(text: text, fontSize: 10.5.sp, color: color),
          ],
        ),
      ),
    );
  }
}

// Lab Activity 6 - Enhancement 3: jump back to the latest message; pops in
// when scrolled up and shows how many new messages arrived meanwhile.
class _ScrollDownButton extends StatelessWidget {
  const _ScrollDownButton({
    required this.visible,
    required this.unread,
    required this.onTap,
  });

  final bool visible;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: visible ? 1 : 0.6,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: FloatingActionButton.small(
              heroTag: null,
              elevation: 2,
              tooltip: 'Latest messages',
              onPressed: onTap,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

// Lab Activity 6 - Enhancement 3: Date separator (Today / Yesterday / date).
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomText(
          text: _formatDay(date),
          fontSize: 11.sp,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

// Lab Activity 6 - Enhancement 3: Empty chat state that fades in.
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56.sp,
              color: colors.primary.withValues(alpha: 0.6),
            ),
            SizedBox(height: 12.h),
            CustomText(
              text: 'No messages yet',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            SizedBox(height: 4.h),
            CustomText(
              text: name.isNotEmpty ? 'Say hi to $name!' : 'Say hi!',
              fontSize: 13.sp,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// Lab Activity 6: shown when the chat can't be opened; keeps the app bar so
// the user can go back.
class _ChatErrorScaffold extends StatelessWidget {
  const _ChatErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48.sp,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: 12.h),
              CustomText(
                text: message,
                fontSize: 14.sp,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
