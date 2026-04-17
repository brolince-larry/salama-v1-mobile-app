// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

// // ── Reverb config matching your .env ─────────────────────────────────────────
// const _kAppKey    = 'ewe4blzwmkn5lxrn6cg1';
// const _kHost      = 'localhost';
// const _kPort      = 8080;
// const _kScheme    = 'http';
// const _kCluster   = 'mt1'; // required by SDK but ignored by Reverb

// typedef EventCallback = void Function(Map<String, dynamic> data);

// class WebSocketService {
//   WebSocketService._();
//   static final WebSocketService instance = WebSocketService._();

//   final _pusher = PusherChannelsFlutter.getInstance();
//   bool _connected = false;

//   final Map<String, Map<String, EventCallback>> _listeners = {};

//   // ── Connect to Reverb ─────────────────────────────────────────────────────
//   Future<void> connect({String? authToken}) async {
//     if (_connected) return;
//     try {
//       await _pusher.init(
//         apiKey: _kAppKey,
//         cluster: _kCluster,
//         wsHost: _kHost,
//         wsPort: _kPort,
//         wssPort: _kPort,
//         useTLS: _kScheme == 'https',
//         forceTLS: _kScheme == 'https',
//         disableStatsWithBetaAuthorizer: true,
//         authEndpoint: authToken != null
//             ? 'http://$_kHost:8000/broadcasting/auth'
//             : null,
//         authParams: authToken != null
//             ? {
//                 'headers': {
//                   'Authorization': 'Bearer $authToken',
//                   'Accept': 'application/json',
//                 }
//               }
//             : null,
//         onConnectionStateChange: (current, previous) {
//           debugPrint(
//               '[WS] State: $previous → $current');
//           _connected = current == 'CONNECTED';
//         },
//         onError: (message, code, error) {
//           debugPrint('[WS] Error $code: $message');
//         },
//         onEvent: (event) {
//           _dispatch(event.channelName, event.eventName,
//               event.data);
//         },
//       );
//       await _pusher.connect();
//       debugPrint('[WS] Connecting to Reverb...');
//     } catch (e) {
//       debugPrint('[WS] Connect failed: $e');
//     }
//   }

//   // ── Subscribe to a public channel ─────────────────────────────────────────
//   Future<void> subscribePublic(String channel) async {
//     try {
//       await _pusher.subscribe(channelName: channel);
//       debugPrint('[WS] Subscribed: $channel');
//     } catch (e) {
//       debugPrint('[WS] Subscribe failed: $e');
//     }
//   }

//   // ── Subscribe to a private channel (requires auth token) ─────────────────
//   Future<void> subscribePrivate(String channel) async {
//     try {
//       await _pusher.subscribe(
//           channelName: 'private-$channel');
//       debugPrint('[WS] Subscribed private: $channel');
//     } catch (e) {
//       debugPrint('[WS] Private subscribe failed: $e');
//     }
//   }

//   // ── Unsubscribe ───────────────────────────────────────────────────────────
//   Future<void> unsubscribe(String channel) async {
//     try {
//       await _pusher.unsubscribe(channelName: channel);
//       _listeners.remove(channel);
//     } catch (e) {
//       debugPrint('[WS] Unsubscribe failed: $e');
//     }
//   }

//   // ── Listen to specific event on channel ───────────────────────────────────
//   void on(String channel, String event, EventCallback cb) {
//     _listeners[channel] ??= {};
//     _listeners[channel]![event] = cb;
//   }

//   // ── Remove listener ───────────────────────────────────────────────────────
//   void off(String channel, String event) {
//     _listeners[channel]?.remove(event);
//   }

//   // ── Dispatch incoming event to registered listeners ───────────────────────
//   void _dispatch(
//       String? channel, String? event, dynamic rawData) {
//     if (channel == null || event == null) return;
//     final cb = _listeners[channel]?[event];
//     if (cb == null) return;

//     try {
//       final data = rawData is String
//           ? json.decode(rawData) as Map<String, dynamic>
//           : rawData as Map<String, dynamic>;
//       cb(data);
//     } catch (e) {
//       debugPrint('[WS] Dispatch error: $e');
//     }
//   }

//   // ── Disconnect ────────────────────────────────────────────────────────────
//   Future<void> disconnect() async {
//     await _pusher.disconnect();
//     _connected = false;
//     _listeners.clear();
//   }
// }