// SAVE AS: lib/features/messaging/presentation/widgets/messaging_widgets.dart

import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../domain/entities/message_entities.dart';

// ── Colour helper ─────────────────────────────────────────────────────────────

Color _hexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ── Thread tile — WhatsApp style ──────────────────────────────────────────────

class ThreadTile extends StatelessWidget {
  final ChatThread thread;
  final bool isDark;
  final VoidCallback onTap;

  const ThreadTile({
    super.key,
    required this.thread,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread  = thread.hasUnread;
    final avatarColor = _hexColor(thread.avatarColor, AppTheme.primary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppTheme.darkBorder
                  : AppTheme.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(children: [
          // ── Avatar ─────────────────────────────────────────────────────
          _Avatar(
            thread:      thread,
            color:       avatarColor,
            hasUnread:   hasUnread,
          ),
          const SizedBox(width: 13),

          // ── Content ────────────────────────────────────────────────────
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + time
              Row(children: [
                Expanded(
                  child: Text(thread.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightText,
                      )),
                ),
                if (thread.lastTime != null)
                  Text(
                    _timeLabel(thread.lastTime!),
                    style: TextStyle(
                      fontSize: 11,
                      color: hasUnread
                          ? AppTheme.primary
                          : (isDark ? AppTheme.textHint : AppTheme.lightHint),
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
              ]),

              // Sub-label: "Parent of Brian" | "6 of 12 boarded" | "Driver"
              if (thread.sublabel != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  if (thread.isGroup) ...[
                    Icon(Icons.group_rounded, size: 11,
                        color: isDark ? AppTheme.textHint : AppTheme.lightHint),
                    const SizedBox(width: 3),
                  ],
                  Expanded(
                    child: Text(thread.sublabel!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted,
                        )),
                  ),
                ]),
              ],

              // Boarding status pill (driver group only)
              if (thread.isGroup &&
                  thread.boardedCount != null &&
                  thread.totalCount != null) ...[
                const SizedBox(height: 4),
                _BoardingProgress(
                    boarded: thread.boardedCount!,
                    total:   thread.totalCount!),
              ],

              // Last message preview
              const SizedBox(height: 3),
              Row(children: [
                // Sender name prefix in group threads
                if (thread.isGroup && thread.senderName != null) ...[
                  Text('${thread.senderName}: ',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted)),
                ],
                Expanded(
                  child: Text(
                    thread.lastMessage ?? 'Tap to start chatting',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread
                          ? (isDark ? AppTheme.textPrimary : AppTheme.lightText)
                          : (isDark ? AppTheme.textSecondary : AppTheme.lightMuted),
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                // Unread badge
                if (hasUnread)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ]),
            ],
          )),
        ]),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inHours   < 1)  return '${diff.inMinutes}m';
    if (diff.inDays    < 1)  return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    if (diff.inDays    < 7)  return _weekday(dt.weekday);
    return '${dt.day}/${dt.month}';
  }

  String _weekday(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final ChatThread thread;
  final Color color;
  final bool hasUnread;
  const _Avatar({required this.thread, required this.color, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      // Photo or initials circle
      thread.photo != null
          ? CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(thread.photo!),
              backgroundColor: color.withValues(alpha: 0.15),
            )
          : CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Text(
                thread.avatarLabel ?? thread.label[0].toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ),

      // Group icon badge bottom-right
      if (thread.isGroup)
        Positioned(
          bottom: -1, right: -1,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.group_rounded, size: 9, color: Colors.white),
          ),
        ),

      // Online dot (for direct threads where we have a driver actively on trip)
      if (!thread.isGroup && thread.senderRole == 'driver')
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            width: 11, height: 11,
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
    ]);
  }
}

// ── Boarding progress pill ────────────────────────────────────────────────────

class _BoardingProgress extends StatelessWidget {
  final int boarded;
  final int total;
  const _BoardingProgress({required this.boarded, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? boarded / total : 0.0;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 3,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            color: AppTheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('$boarded/$total',
          style: const TextStyle(
              color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Inbox section header ──────────────────────────────────────────────────────

class InboxSectionHeader extends StatelessWidget {
  final String label;
  const InboxSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: dark ? AppTheme.black : AppTheme.lightBg,
      child: Text(label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: dark ? AppTheme.textHint : AppTheme.lightHint,
            letterSpacing: 1.1,
          )),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final int currentUserId;
  final bool isDark;
  final bool isGroup;

  const ChatBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.isDark,
    this.isGroup = false,
  });

  bool get _isMe => message.senderId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left:  _isMe ? 60 : 0,
        right: _isMe ? 0  : 60,
      ),
      child: Row(
        mainAxisAlignment: _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender avatar (other person only, group chats)
          if (!_isMe && isGroup) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isMe
                    ? AppTheme.primary
                    : (isDark ? AppTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(_isMe ? 18 : 4),
                  bottomRight: Radius.circular(_isMe ? 4  : 18),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Broadcast alert badge
                  if (message.isBroadcast)
                    _AlertBadge(category: message.alertCategory, isMe: _isMe),

                  // Sender name in group
                  if (!_isMe && isGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(message.senderName,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                    ),

                  // Message body
                  Text(message.body,
                      style: TextStyle(
                        color: _isMe
                            ? Colors.white
                            : (isDark ? AppTheme.textPrimary : AppTheme.lightText),
                        fontSize: 14,
                        height: 1.4,
                      )),

                  // Timestamp
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTime(message.at),
                      style: TextStyle(
                        fontSize: 10,
                        color: _isMe
                            ? Colors.white60
                            : (isDark ? AppTheme.textHint : AppTheme.lightHint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }
}

class _AlertBadge extends StatelessWidget {
  final String? category;
  final bool isMe;
  const _AlertBadge({this.category, required this.isMe});

  static const _icons = <String, IconData>{
    'delay':        Icons.schedule_rounded,
    'breakdown':    Icons.car_crash_rounded,
    'accident':     Icons.warning_amber_rounded,
    'route_change': Icons.alt_route_rounded,
    'general':      Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon  = _icons[category] ?? Icons.campaign_rounded;
    final label = (category ?? 'alert').replaceAll('_', ' ').toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : AppTheme.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11,
              color: isMe ? Colors.white : AppTheme.warning),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isMe ? Colors.white : AppTheme.warning,
                letterSpacing: 0.5,
              )),
        ]),
      ),
    );
  }
}

// ── Incoming message popup ────────────────────────────────────────────────────

class IncomingMessageBanner extends StatelessWidget {
  final IncomingMessage incoming;
  final VoidCallback onReply;
  final VoidCallback onDismiss;

  const IncomingMessageBanner({
    super.key,
    required this.incoming,
    required this.onReply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(
              incoming.message.senderName.isNotEmpty
                  ? incoming.message.senderName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(incoming.message.senderName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(incoming.threadLabel,
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(incoming.message.body,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ])),
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: onReply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Reply',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Message input bar ─────────────────────────────────────────────────────────

class MessageInputBar extends StatefulWidget {
  final bool sending;
  final bool isDark;
  final void Function(String) onSend;
  final VoidCallback? onBroadcast; // shown for group threads instead of text input

  const MessageInputBar({
    super.key,
    required this.sending,
    required this.isDark,
    required this.onSend,
    this.onBroadcast,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty || widget.sending) return;
    widget.onSend(t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Group thread: show broadcast button instead
    if (widget.onBroadcast != null) {
      return Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
        decoration: BoxDecoration(
          color: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border(top: BorderSide(
              color: widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ),
        child: FilledButton.icon(
          onPressed: widget.onBroadcast,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.campaign_rounded, size: 18),
          label: const Text('Send Alert to Group',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkSurface : const Color(0xFFF0F2F5),
        border: Border(top: BorderSide(
            color: widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 0.5),
            ),
            child: TextField(
              controller: _ctrl,
              style: TextStyle(
                  color: widget.isDark ? AppTheme.textPrimary : AppTheme.lightText,
                  fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle: TextStyle(
                    color: widget.isDark ? AppTheme.textHint : AppTheme.lightHint,
                    fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5, minLines: 1,
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
                color: AppTheme.primary, shape: BoxShape.circle),
            child: widget.sending
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── Broadcast sheet ───────────────────────────────────────────────────────────

class BroadcastSheet extends StatefulWidget {
  final bool isDark;
  final String groupType;
  final int scopeId;
  final Future<void> Function({
    required String groupType,
    required int scopeId,
    required String body,
    required String alertCategory,
  }) onSend;

  const BroadcastSheet({
    super.key,
    required this.isDark,
    required this.groupType,
    required this.scopeId,
    required this.onSend,
  });

  @override
  State<BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<BroadcastSheet> {
  final _ctrl = TextEditingController();
  String _cat  = 'general';
  bool _busy   = false;
  bool _done   = false;

  static const _cats = {
    'delay':        (Icons.schedule_rounded,     'Delay'),
    'breakdown':    (Icons.car_crash_rounded,     'Breakdown'),
    'accident':     (Icons.warning_amber_rounded, 'Accident'),
    'route_change': (Icons.alt_route_rounded,     'Route Change'),
    'general':      (Icons.info_outline_rounded,  'General'),
  };

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(
        groupType:     widget.groupType,
        scopeId:       widget.scopeId,
        body:          _ctrl.text.trim(),
        alertCategory: _cat,
      );
      if (mounted) setState(() { _busy = false; _done = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: dark ? AppTheme.darkBorder : AppTheme.lightBorder,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_rounded, color: AppTheme.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Send Alert to Group',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: dark ? AppTheme.textPrimary : AppTheme.lightText)),
            Text('All group members will be notified',
                style: TextStyle(fontSize: 11,
                    color: dark ? AppTheme.textSecondary : AppTheme.lightMuted)),
          ]),
        ]),
        const SizedBox(height: 18),

        // Category chips
        Wrap(spacing: 8, runSpacing: 8,
          children: _cats.entries.map((e) {
            final sel = _cat == e.key;
            return GestureDetector(
              onTap: () => setState(() => _cat = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.danger : (dark ? AppTheme.darkCard : AppTheme.lightCard),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppTheme.danger
                      : (dark ? AppTheme.darkBorder : AppTheme.lightBorder)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.value.$1, size: 13,
                      color: sel ? Colors.white : AppTheme.danger),
                  const SizedBox(width: 5),
                  Text(e.value.$2,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white
                              : (dark ? AppTheme.textPrimary : AppTheme.lightText))),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Message textarea
        TextField(
          controller: _ctrl,
          maxLines: 4, minLines: 3,
          style: TextStyle(
              color: dark ? AppTheme.textPrimary : AppTheme.lightText, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Describe the situation…',
            hintStyle: TextStyle(
                color: dark ? AppTheme.textHint : AppTheme.lightHint),
            filled: true,
            fillColor: dark ? AppTheme.darkCard : AppTheme.lightCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: dark ? AppTheme.darkBorder : AppTheme.lightBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _done ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: _done ? AppTheme.success : AppTheme.danger,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _busy
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(_done ? Icons.check_rounded : Icons.send_rounded, size: 18),
            label: Text(_busy ? 'Sending…' : _done ? 'Sent!' : 'Send to Group',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared empty / error states ───────────────────────────────────────────────

class MessagingEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  const MessagingEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16,
                    color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5,
                    color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted)),
          ]),
        ),
      );
}

class MessagingErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const MessagingErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ]),
      );
}