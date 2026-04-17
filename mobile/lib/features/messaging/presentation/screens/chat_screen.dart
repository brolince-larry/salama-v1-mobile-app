// lib/features/messaging/presentation/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import '../../domain/entities/message_entities.dart';
import '../providers/messaging_providers.dart';
import '../widgets/messaging_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatThread thread;
  const ChatScreen({super.key, required this.thread});

  @override
  ConsumerState<ChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toBottom(jump: true);

      // FIX: Tell the popup notifier the user is viewing this thread.
      // Prevents the incoming-message popup from showing while the chat
      // is open — same behaviour as WhatsApp/Telegram.
      ref
          .read(incomingPopupProvider.notifier)
          .setActiveThread(widget.thread.threadKey);
    });
  }

  @override
  void dispose() {
    // FIX: Clear the active thread so popups resume for other threads.
    ref.read(incomingPopupProvider.notifier).setActiveThread(null);
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool jump = false}) {
    if (!_scroll.hasClients) return;
    if (jump) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    } else {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendDirect(String body) async {
    final id = widget.thread.recipientId;
    final role = widget.thread.recipientRole;
    if (id == null || role == null) return;
    ref
        .read(threadProvider(widget.thread.threadKey).notifier)
        .sendDirect(recipientId: id, recipientRole: role, body: body);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _showBroadcast(BuildContext ctx, bool dark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: dark ? AppTheme.darkCard : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BroadcastSheet(
        isDark: dark,
        groupType: widget.thread.groupType ?? 'general',
        scopeId: widget.thread.scopeId ?? 0,
        onSend: ({
          required groupType,
          required scopeId,
          required body,
          required alertCategory,
        }) async {
          ref
              .read(threadProvider(widget.thread.threadKey).notifier)
              .sendGroup(
                groupType: groupType,
                scopeId: scopeId,
                body: body,
                meta: {'alert_category': alertCategory},
              );
          WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(threadProvider(widget.thread.threadKey));
    final authUser = ref.watch(currentUserProvider);
    final myId = authUser?.id ?? 0;

    // Auto-scroll when new messages arrive
    ref.listen(
      threadProvider(widget.thread.threadKey).select((s) => s.messages.length),
      (prev, next) {
        if ((prev ?? 0) < next) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
        }
      },
    );

    final recipientId = widget.thread.recipientId;
    final isOnline =
        recipientId != null ? (state.presence[recipientId] ?? false) : false;

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      appBar: _ChatAppBar(
        thread: widget.thread,
        isOnline: isOnline,
        dark: dark,
        onBroadcast:
            widget.thread.isGroup ? () => _showBroadcast(context, dark) : null,
      ),
      body: Column(children: [
        if (state.loadingMore)
          const LinearProgressIndicator(
            color: AppTheme.primary,
            backgroundColor: Colors.transparent,
            minHeight: 2,
          ),
        Expanded(
          child: state.loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : state.error != null && state.messages.isEmpty
                  ? _ErrorView(
                      message: state.error!,
                      onRetry: () => ref
                          .read(threadProvider(widget.thread.threadKey)
                              .notifier)
                          .fetch(),
                    )
                  : state.messages.isEmpty
                      ? _EmptyConversation(dark: dark)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification &&
                                _scroll.hasClients &&
                                _scroll.position.pixels <= 0) {
                              ref
                                  .read(threadProvider(widget.thread.threadKey)
                                      .notifier)
                                  .loadMore();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            itemCount: state.messages.length,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: false,
                            itemBuilder: (ctx, i) {
                              final msg = state.messages[i];
                              final prev =
                                  i > 0 ? state.messages[i - 1] : null;
                              final showDate =
                                  prev == null || !_sameDay(prev.at, msg.at);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDate)
                                    _DateDivider(date: msg.at, dark: dark),
                                  _ChatBubble(
                                    msg: msg,
                                    // FIX: senderId == 0 is the optimistic
                                    // placeholder — treat as "mine" until
                                    // the real id comes back from the API.
                                    isMe: msg.senderId == myId ||
                                        msg.senderId == 0,
                                    isGroup: widget.thread.isGroup,
                                    isOnline: isOnline,
                                    dark: dark,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
        ),
        MessageInputBar(
          isDark: dark,
          sending: state.sending,
          onSend: widget.thread.isGroup
              ? (_) => _showBroadcast(context, dark)
              : _sendDirect,
        ),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ChatThread thread;
  final bool isOnline;
  final bool dark;
  final VoidCallback? onBroadcast;

  const _ChatAppBar({
    required this.thread,
    required this.isOnline,
    required this.dark,
    this.onBroadcast,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor:
          dark ? const Color(0xFF1F2C34) : AppTheme.primary,
      titleSpacing: 0,
      title: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                _hexColor(thread.avatarColor, AppTheme.primaryLight),
            child: Text(
              thread.avatarLabel ?? thread.label[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF1F2C34)
                        : AppTheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(thread.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text(
                  isOnline
                      ? 'online'
                      : (thread.isGroup
                          ? '${thread.memberCount ?? ''} members'
                          : 'offline'),
                  style: TextStyle(
                      color: isOnline
                          ? const Color(0xFF25D366)
                          : Colors.white60,
                      fontSize: 11),
                ),
              ]),
        ),
      ]),
      actions: [
        if (onBroadcast != null)
          IconButton(
            icon: const Icon(Icons.campaign_rounded, color: Colors.white),
            onPressed: onBroadcast,
          ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Color _hexColor(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final bool isGroup;
  final bool isOnline;
  final bool dark;

  const _ChatBubble({
    required this.msg,
    required this.isMe,
    required this.isGroup,
    required this.isOnline,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 8,
        right: isMe ? 8 : 60,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isGroup) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(
                  msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? (dark
                        ? const Color(0xFF005C4B)
                        : const Color(0xFFDCF8C6))
                    : (dark ? const Color(0xFF1F2C34) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && isGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(msg.senderName,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  Text(
                    msg.body,
                    style: TextStyle(
                      color: dark
                          ? Colors.white
                          : const Color(0xFF111111),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _time(msg.at),
                        style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? (dark ? Colors.white54 : Colors.black38)
                                : Colors.grey),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        _StatusTick(
                            status: msg.status, isOnline: isOnline),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── WhatsApp-style ticks ──────────────────────────────────────────────────────

class _StatusTick extends StatelessWidget {
  final MessageStatus status;
  final bool isOnline;
  const _StatusTick({required this.status, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 12, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded, size: 14, color: Colors.grey);
      case MessageStatus.delivered:
        return const _DoubleTick(color: Colors.grey);
      case MessageStatus.read:
        return const _DoubleTick(color: Color(0xFF53BDEB));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 12, color: Colors.red);
    }
  }
}

class _DoubleTick extends StatelessWidget {
  final Color color;
  const _DoubleTick({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Stack(children: [
        Positioned(
            left: 0,
            child: Icon(Icons.done_rounded, size: 14, color: color)),
        Positioned(
            left: 5,
            child: Icon(Icons.done_rounded, size: 14, color: color)),
      ]),
    );
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final bool dark;
  const _DateDivider({required this.date, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
            child: Divider(
                color: dark ? Colors.white12 : Colors.black12)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 2)
            ],
          ),
          child: Text(_label(date),
              style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(
                color: dark ? Colors.white12 : Colors.black12)),
      ]),
    );
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  final bool dark;
  const _EmptyConversation({required this.dark});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56,
              color: dark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Say hi 👋',
              style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 12)),
        ]),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                color: AppTheme.danger, size: 40),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.danger, fontSize: 12)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}