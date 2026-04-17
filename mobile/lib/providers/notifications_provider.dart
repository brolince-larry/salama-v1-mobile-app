// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../models/app_notification.dart';
// import '../models/user.dart';
// import '../services/websocket_service.dart';
// import '../services/auth_service.dart';
// import 'auth_provider.dart';

// class NotificationState {
//   final List<AppNotification> notifications;
//   final bool connected;

//   const NotificationState({
//     this.notifications = const [],
//     this.connected = false,
//   });

//   int get unreadCount =>
//       notifications.where((n) => !n.read).length;

//   NotificationState copyWith({
//     List<AppNotification>? notifications,
//     bool? connected,
//   }) =>
//       NotificationState(
//         notifications: notifications ?? this.notifications,
//         connected: connected ?? this.connected,
//       );
// }

// class NotificationNotifier
//     extends StateNotifier<NotificationState> {
//   final Ref _ref;
//   final _ws = WebSocketService.instance;

//   NotificationNotifier(this._ref)
//       : super(const NotificationState());

//   Future<void> connect() async {
//     final user = _ref.read(currentUserProvider);
//     if (user == null) return;

//     // Get token directly from AuthService secure storage
//     final token = await AuthService.getToken();

//     await _ws.connect(authToken: token);

//     if (user.isSchoolAdmin || user.isSuperAdmin) {
//       await _subscribeAdmin(user);
//     } else if (user.isParent) {
//       await _subscribeParent(user);
//     } else if (user.isDriver) {
//       await _subscribeDriver(user);
//     }

//     state = state.copyWith(connected: true);
//   }

//   Future<void> _subscribeAdmin(UserModel user) async {
//     final ch = 'school.${user.schoolId}';
//     await _ws.subscribePublic(ch);

//     _ws.on(ch, 'location.updated',
//         (d) => _updateBusLocation(d));
//     _ws.on(ch, 'sos.triggered',
//         (d) => _add(AppNotification.sosTriggered(d)));
//     _ws.on(ch, 'trip.started',
//         (d) => _add(AppNotification.tripStarted(d)));
//     _ws.on(ch, 'trip.ended',
//         (d) => _add(AppNotification.tripEnded(d)));
//   }

//   Future<void> _subscribeParent(UserModel user) async {
//     final ch = 'parent.${user.id}';
//     await _ws.subscribePrivate(ch);

//     _ws.on('private-$ch', 'bus.arrived.child.stop',
//         (d) => _add(AppNotification.busArrived(d)));
//     _ws.on('private-$ch', 'child.boarded',
//         (d) => _add(AppNotification.studentBoarded(d)));
//   }

//   Future<void> _subscribeDriver(UserModel user) async {
//     final ch = 'school.${user.schoolId}';
//     await _ws.subscribePublic(ch);
//     _ws.on(ch, 'trip.started',
//         (d) => _add(AppNotification.tripStarted(d)));
//   }

//   void _updateBusLocation(Map<String, dynamic> d) {
//     // Silent update — fleet provider handles map update
//   }

//   void _add(AppNotification n) {
//     final updated = [n, ...state.notifications];
//     if (updated.length > 50) updated.removeLast();
//     state = state.copyWith(notifications: updated);
//   }

//   void markRead(String id) {
//     final updated = state.notifications.map((n) {
//       if (n.id == id) n.read = true;
//       return n;
//     }).toList();
//     state = state.copyWith(notifications: updated);
//   }

//   void markAllRead() {
//     final updated = state.notifications
//         .map((n) { n.read = true; return n; }).toList();
//     state = state.copyWith(notifications: updated);
//   }

//   void clear() => state = const NotificationState();

//   @override
//   void dispose() {
//     _ws.disconnect();
//     super.dispose();
//   }
// }

// final notificationProvider = StateNotifierProvider
//     NotificationNotifier, NotificationState>((ref) {
//   return NotificationNotifier(ref);
// });