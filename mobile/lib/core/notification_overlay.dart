// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../config/app_theme.dart';
// import '../models/app_notification.dart';
// import '../providers/notification_provider.dart';

// // ── Wrap your app with this to get auto toasts ────────────────────────────────
// class NotificationOverlay extends ConsumerStatefulWidget {
//   final Widget child;
//   const NotificationOverlay({super.key, required this.child});

//   @override
//   ConsumerState<NotificationOverlay> createState() => _State();
// }

// class _State extends ConsumerState<NotificationOverlay> {
//   AppNotification? _current;
//   OverlayEntry? _entry;

//   @override
//   void initState() {
//     super.initState();
//     // Connect WebSocket after first frame
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       ref.read(notificationProvider.notifier).connect();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Watch for new notifications
//     ref.listen<NotificationState>(notificationProvider,
//         (prev, next) {
//       if (next.notifications.isEmpty) return;
//       final latest = next.notifications.first;
//       if (prev != null &&
//           prev.notifications.isNotEmpty &&
//           prev.notifications.first.id == latest.id) return;

//       // Show toast for new notification
//       _showToast(context, latest);
//     });

//     return child;
//   }

//   Widget get child => widget.child;

//   void _showToast(
//       BuildContext context, AppNotification n) {
//     _entry?.remove();
//     _entry = OverlayEntry(
//       builder: (_) => _Toast(
//         notification: n,
//         onDismiss: () {
//           _entry?.remove();
//           _entry = null;
//         },
//       ),
//     );
//     Overlay.of(context).insert(_entry!);
//   }
// }

// // ── Toast widget ──────────────────────────────────────────────────────────────
// class _Toast extends StatefulWidget {
//   final AppNotification notification;
//   final VoidCallback onDismiss;
//   const _Toast(
//       {required this.notification, required this.onDismiss});

//   @override
//   State<_Toast> createState() => _ToastState();
// }

// class _ToastState extends State<_Toast>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<Offset> _slide;
//   late Animation<double> _fade;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//         vsync: this,
//         duration: const Duration(milliseconds: 400));
//     _slide = Tween<Offset>(
//       begin: const Offset(0, -1),
//       end: Offset.zero,
//     ).animate(
//         CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
//     _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);

//     _ctrl.forward();

//     // Auto dismiss after 4 seconds
//     Future.delayed(const Duration(seconds: 4), () {
//       if (mounted) _dismiss();
//     });
//   }

//   void _dismiss() async {
//     await _ctrl.reverse();
//     widget.onDismiss();
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   Color get _color {
//     switch (widget.notification.type) {
//       case NotificationType.sosTriggered:
//         return AppTheme.danger;
//       case NotificationType.busArrived:
//         return AppTheme.success;
//       case NotificationType.studentBoarded:
//         return AppTheme.info;
//       case NotificationType.tripStarted:
//         return AppTheme.primary;
//       case NotificationType.tripEnded:
//         return AppTheme.success;
//       case NotificationType.busLocation:
//         return AppTheme.info;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final topPad = MediaQuery.of(context).padding.top;

//     return Positioned(
//       top: topPad + 8,
//       left: 16,
//       right: 16,
//       child: SlideTransition(
//         position: _slide,
//         child: FadeTransition(
//           opacity: _fade,
//           child: Material(
//             color: Colors.transparent,
//             child: GestureDetector(
//               onTap: _dismiss,
//               onVerticalDragEnd: (d) {
//                 if (d.primaryVelocity! < 0) _dismiss();
//               },
//               child: Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF1A1A1A),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(
//                       color: _color.withValues(alpha: 0.4),
//                       width: 1.5),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black
//                           .withValues(alpha: 0.4),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                     BoxShadow(
//                       color: _color.withValues(alpha: 0.15),
//                       blurRadius: 20,
//                     ),
//                   ],
//                 ),
//                 child: Row(children: [
//                   // Icon
//                   Container(
//                     padding: const EdgeInsets.all(9),
//                     decoration: BoxDecoration(
//                       color: _color.withValues(alpha: 0.15),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Text(
//                       widget.notification.title
//                           .split(' ')
//                           .first,
//                       style: const TextStyle(fontSize: 18),
//                     ),
//                   ),
//                   const SizedBox(width: 12),

//                   // Text
//                   Expanded(
//                     child: Column(
//                         crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                         children: [
//                       Text(
//                         widget.notification.title
//                             .split(' ')
//                             .skip(1)
//                             .join(' '),
//                         style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         widget.notification.message,
//                         style: TextStyle(
//                             color: Colors.white
//                                 .withValues(alpha: 0.7),
//                             fontSize: 11),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ]),
//                   ),

//                   // Dismiss
//                   GestureDetector(
//                     onTap: _dismiss,
//                     child: Icon(Icons.close,
//                         color: Colors.white
//                             .withValues(alpha: 0.5),
//                         size: 16),
//                   ),
//                 ]),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Notification bell widget (use in top bars) ────────────────────────────────
// class NotificationBell extends ConsumerWidget {
//   const NotificationBell({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final count =
//         ref.watch(notificationProvider).unreadCount;

//     return Stack(clipBehavior: Clip.none, children: [
//       const Icon(Icons.notifications_outlined,
//           color: Colors.white, size: 22),
//       if (count > 0)
//         Positioned(
//           right: -4,
//           top: -4,
//           child: Container(
//             padding: const EdgeInsets.all(3),
//             decoration: const BoxDecoration(
//                 color: AppTheme.danger,
//                 shape: BoxShape.circle),
//             child: Text(
//               count > 9 ? '9+' : '$count',
//               style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 9,
//                   fontWeight: FontWeight.w700),
//             ),
//           ),
//         ),
//     ]);
//   }
// }