import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message_entities.dart';
import '../providers/messaging_providers.dart';
import '../screens/chat_screen.dart';
import 'messaging_widgets.dart';

class MessagingOverlay extends ConsumerWidget {
  final Widget child;
  const MessagingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<IncomingMessage?>(incomingPopupProvider, (prev, next) {
      if (next != null) {
        // Optional: Trigger a sound or haptic feedback here
      }
    });

    final incoming = ref.watch(incomingPopupProvider);

    return Material( 
      child: Stack(
        children: [
          child,
          if (incoming != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _AnimatedBanner(
                key: ValueKey(incoming.message.id), 
                incoming: incoming,
                onReply: () {
                  final message = incoming.message;
                  ref.read(incomingPopupProvider.notifier).dismiss();
                  _navigateToChat(context, ref, message);
                },
                onDismiss: () =>
                    ref.read(incomingPopupProvider.notifier).dismiss(),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToChat(BuildContext context, WidgetRef ref, ChatMessage message) {
    final existingThread = ref.read(inboxProvider).threads
        .where((t) => t.threadKey == message.threadKey)
        .firstOrNull;

    final threadToOpen = existingThread ?? ChatThread(
      threadKey: message.threadKey,
      threadType: message.threadKey.startsWith('group_') ? 'group' : 'direct', 
      label: message.senderName,
      lastMessage: message.body,
      lastTime: message.at,
      unreadCount: 0,
    );

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(thread: threadToOpen),
    ));
  }
}

// ONLY ONE DECLARATION OF THIS CLASS ALLOWED
class _AnimatedBanner extends StatefulWidget {
  final IncomingMessage incoming;
  final VoidCallback onReply;
  final VoidCallback onDismiss;

  const _AnimatedBanner({
    super.key, 
    required this.incoming,
    required this.onReply,
    required this.onDismiss,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: IncomingMessageBanner(
          incoming:  widget.incoming,
          onReply:   widget.onReply,
          onDismiss: widget.onDismiss,
        ),
      ),
    );
  }
}