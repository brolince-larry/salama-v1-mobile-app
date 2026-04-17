// SAVE AS: lib/features/messaging/presentation/screens/inbox_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../providers/messaging_providers.dart';
import '../widgets/messaging_widgets.dart';
import 'chat_screen.dart';
import '../../domain/entities/message_entities.dart';

class MessagingInboxScreen extends ConsumerStatefulWidget {
  const MessagingInboxScreen({super.key});

  @override
  ConsumerState<MessagingInboxScreen> createState() => _InboxState();
}

class _InboxState extends ConsumerState<MessagingInboxScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxProvider);
    final dark  = Theme.of(context).brightness == Brightness.dark;

    // Split groups and direct threads
    final all     = state.threads;
    final filtered = _query.isEmpty
        ? all
        : all.where((t) =>
            t.label.toLowerCase().contains(_query.toLowerCase()) ||
            (t.sublabel?.toLowerCase().contains(_query.toLowerCase()) ?? false) ||
            (t.lastMessage?.toLowerCase().contains(_query.toLowerCase()) ?? false))
          .toList();

    final groups  = filtered.where((t) => t.isGroup).toList();
    final directs = filtered.where((t) => !t.isGroup).toList();
    final totalUnread = all.fold<int>(0, (s, t) => s + t.unreadCount);

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Messages',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          if (totalUnread > 0)
            Text('$totalUnread unread',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(inboxProvider.notifier).fetch(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search messages…',
                  hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white60, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : state.error != null
              ? MessagingErrorState(
                  message: state.error!,
                  onRetry: () => ref.read(inboxProvider.notifier).fetch(),
                )
              : filtered.isEmpty
                  ? MessagingEmptyState(
                      title:    _query.isEmpty ? 'No conversations yet' : 'No results',
                      subtitle: _query.isEmpty
                          ? 'Your chats will appear here\nonce a trip is active.'
                          : 'Try a different search term.',
                      isDark: dark,
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(inboxProvider.notifier).fetch(),
                      color: AppTheme.primary,
                      child: ListView(
                        children: [
                          // ── Group threads ───────────────────────────────
                          if (groups.isNotEmpty) ...[
                            const InboxSectionHeader(label: 'Groups'),
                            ...groups.map((t) => ThreadTile(
                                  thread: t,
                                  isDark: dark,
                                  onTap:  () => _open(context, ref, t),
                                )),
                          ],

                          // ── Direct threads ──────────────────────────────
                          if (directs.isNotEmpty) ...[
                            const InboxSectionHeader(label: 'Direct Messages'),
                            ...directs.map((t) => ThreadTile(
                                  thread: t,
                                  isDark: dark,
                                  onTap:  () => _open(context, ref, t),
                                )),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

      // ── Incoming popup overlay ──────────────────────────────────────────────
      floatingActionButton: Consumer(builder: (ctx, ref, _) {
        final incoming = ref.watch(incomingPopupProvider);
        if (incoming == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IncomingMessageBanner(
            incoming:  incoming,
            onReply:   () {
              ref.read(incomingPopupProvider.notifier).dismiss();
              final match = state.threads
                  .where((t) => t.threadKey == incoming.message.threadKey)
                  .firstOrNull;
              if (match != null) _open(ctx, ref, match);
            },
            onDismiss: () => ref.read(incomingPopupProvider.notifier).dismiss(),
          ),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _open(BuildContext ctx, WidgetRef ref, ChatThread thread) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => ChatScreen(thread: thread),
    )).then((_) => ref.read(inboxProvider.notifier).fetch());
  }
}