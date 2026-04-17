// lib/features/messaging/data/repositories/messaging_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/message_entities.dart';
import '../../domain/repositories/i_messaging_repository.dart';
import '../datasources/messaging_remote_datasource.dart';
import '../models/message_models.dart';

class MessagingRepository implements IMessagingRepository {
  final MessagingRemoteDatasource _datasource;
  int _userId;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  String? _socketId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connected = false;
  int _reconnectAttempts = 0;

  Uri? _wsUri;
  String? _authEndpoint;
  String? _baseUrl;
  Future<String> Function()? _getToken;

  final _seenIds    = <int>{};
  final _onlineUsers = <int>{};

  // ── Public streams ─────────────────────────────────────────────────────
  final _incomingCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingStream => _incomingCtrl.stream;

  final _presenceCtrl = StreamController<Map<int, bool>>.broadcast();
  Stream<Map<int, bool>> get presenceStream => _presenceCtrl.stream;

  final _readCtrl =
      StreamController<({String threadKey, int userId})>.broadcast();
  Stream<({String threadKey, int userId})> get readReceiptStream =>
      _readCtrl.stream;

  bool isUserOnline(int userId) => _onlineUsers.contains(userId);

  int get userId  => _userId;
  @override
  set userId(int id) => _userId = id;

  MessagingRepository({
    required MessagingRemoteDatasource datasource,
    int userId = 0,
    dynamic pusher,
  })  : _datasource = datasource,
        _userId = userId;

  MessagingRepository.withoutPusher({
    required MessagingRemoteDatasource datasource,
  })  : _datasource = datasource,
        _userId = 0;

  // ── Connect ────────────────────────────────────────────────────────────

  Future<void> initWithReverb({
    required Uri wsUri,
    required String authEndpoint,
    required Future<String> Function() getToken,
  }) async {
    _wsUri = wsUri;
    _authEndpoint = authEndpoint;
    _baseUrl = authEndpoint.replaceAll('/broadcasting/auth', '');
    _getToken = getToken;
    _reconnectAttempts = 0;
    await _connect();
  }

  @override
  Future<void> init() async {
    if (_wsUri != null && !_connected) await _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _userId == 0 || _wsUri == null) return;
    await _closeSocket();
    try {
      debugPrint('[Reverb] connecting → $_wsUri');
      _channel = WebSocketChannel.connect(_wsUri!);
      _wsSub = _channel!.stream.listen(
        _onRaw,
        onDone: _onDisconnected,
        onError: (e) => debugPrint('[Reverb] stream error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[Reverb] connect failed: $e');
      _scheduleReconnect();
    }
  }

  // ── Pusher wire protocol ───────────────────────────────────────────────

  void _onRaw(dynamic raw) {
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = frame['event'] as String? ?? '';
      final chan   = frame['channel'] as String? ?? '';

      debugPrint('[Reverb] ← $event  chan=$chan');

      switch (event) {
        case 'pusher:connection_established':
          final d = jsonDecode(frame['data'] as String) as Map<String, dynamic>;
          _socketId  = d['socket_id'] as String?;
          _connected = true;
          _reconnectAttempts = 0;
          debugPrint('[Reverb] ✅ connected  socket_id=$_socketId');
          _subscribePrivate();
          _subscribePresence();
          // Re-subscribe any dynamic channels that were requested before
          // the connection was (re)established.
          _resubscribeDynamicChannels();
          _startPing();

        case 'pusher_internal:subscription_succeeded':
          debugPrint('[Reverb] ✅ subscribed to $chan');
          if (chan.startsWith('presence-')) {
            _handlePresenceMemberList(frame['data']);
          }

        case 'message.sent':
          _handleMessageSent(frame['data']);

        case 'message.read':
          _handleReadReceipt(frame['data']);

        case 'pusher_internal:member_added':
          _handleMemberAdded(frame['data']);

        case 'pusher_internal:member_removed':
          _handleMemberRemoved(frame['data']);

        case 'pusher:pong':
          break;

        default:
          // Route to any dynamic channel listener (e.g. BusLocationUpdated)
          if (chan.isNotEmpty && event.isNotEmpty &&
              !event.startsWith('pusher:')) {
            _routeToDynamic(chan, event, _parseData(frame['data']));
            debugPrint('[Reverb] dynamic event: $event on $chan');
          }
      }
    } catch (e, st) {
      debugPrint('[Reverb] parse error: $e\n$st');
    }
  }

  // ── Event handlers ─────────────────────────────────────────────────────

  void _handleMessageSent(dynamic data) {
    final map = _parseData(data);
    if (map.isEmpty) return;
    try {
      final msg = ChatMessageModel.fromPusher(map);
      if (_seenIds.contains(msg.id)) return;
      _seenIds.add(msg.id);
      if (_seenIds.length > 300) _seenIds.remove(_seenIds.first);
      if (!_incomingCtrl.isClosed) _incomingCtrl.add(msg);
      debugPrint('[Reverb] 📨 message ${msg.id} in ${msg.threadKey}');
    } catch (e) {
      debugPrint('[Reverb] message parse error: $e  data=$map');
    }
  }

  void _handleReadReceipt(dynamic data) {
    final map       = _parseData(data);
    final threadKey = map['thread_key'] as String?;
    final readerId  = _toInt(map['user_id']);
    if (threadKey != null && readerId != null && !_readCtrl.isClosed) {
      _readCtrl.add((threadKey: threadKey, userId: readerId));
      debugPrint('[Reverb] 👁 read receipt user=$readerId thread=$threadKey');
    }
  }

  void _handlePresenceMemberList(dynamic data) {
    final map      = _parseData(data);
    final presence = map['presence'] as Map?;
    if (presence == null) return;
    final hash = presence['hash'] as Map?;
    hash?.forEach((key, _) {
      final uid = _toInt(key);
      if (uid != null && uid != _userId) {
        _onlineUsers.add(uid);
        if (!_presenceCtrl.isClosed) _presenceCtrl.add({uid: true});
      }
    });
    debugPrint('[Reverb] 👥 online users: $_onlineUsers');
  }

  void _handleMemberAdded(dynamic data) {
    final map = _parseData(data);
    final uid = _toInt(map['user_id']);
    if (uid != null && uid != _userId) {
      _onlineUsers.add(uid);
      if (!_presenceCtrl.isClosed) _presenceCtrl.add({uid: true});
      debugPrint('[Reverb] 🟢 user $uid online');
    }
  }

  void _handleMemberRemoved(dynamic data) {
    final map = _parseData(data);
    final uid = _toInt(map['user_id']);
    if (uid != null) {
      _onlineUsers.remove(uid);
      if (!_presenceCtrl.isClosed) _presenceCtrl.add({uid: false});
      debugPrint('[Reverb] 🔴 user $uid offline');
    }
  }

  // ── Static channel subscriptions ──────────────────────────────────────

  Future<void> _subscribePrivate() async {
    if (_socketId == null || _getToken == null || _authEndpoint == null) return;
    final channel = 'private-user.$_userId';
    final auth    = await _getChannelAuth(channel);
    if (auth == null) {
      debugPrint('[Reverb] ❌ auth failed for $channel');
      return;
    }
    _send({'event': 'pusher:subscribe', 'data': {'channel': channel, 'auth': auth}});
    debugPrint('[Reverb] → subscribing $channel');
  }

  Future<void> _subscribePresence() async {
    if (_socketId == null || _getToken == null || _authEndpoint == null) return;
    const channel     = 'presence-online';
    final channelData = jsonEncode({'user_id': _userId, 'user_info': {'id': _userId}});
    final auth        = await _getChannelAuth(channel, channelData: channelData);
    if (auth == null) {
      debugPrint('[Reverb] ⚠️ presence auth failed (optional feature)');
      return;
    }
    _send({
      'event': 'pusher:subscribe',
      'data':  {'channel': channel, 'auth': auth, 'channel_data': channelData},
    });
    debugPrint('[Reverb] → subscribing $channel');
  }

  Future<String?> _getChannelAuth(String channel, {String? channelData}) async {
    try {
      final token = await _getToken!();
      final body  = <String, String>{
        'channel_name': channel,
        'socket_id':    _socketId!,
      };
      if (channelData != null) body['channel_data'] = channelData;

      final res = await http.post(
        Uri.parse(_authEndpoint!),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/x-www-form-urlencoded',
          'Accept':        'application/json',
        },
        body: body,
      );
      debugPrint('[Reverb] auth $channel → ${res.statusCode}');
      if (res.statusCode != 200) {
        debugPrint('[Reverb] auth body: ${res.body}');
        return null;
      }
      return (jsonDecode(res.body) as Map)['auth'] as String?;
    } catch (e) {
      debugPrint('[Reverb] auth error: $e');
      return null;
    }
  }

  // ── Dynamic channel subscriptions ─────────────────────────────────────
  //
  // subscribeToChannel() lets any provider (e.g. FleetNotifier) attach to
  // an arbitrary Reverb channel+event without a dedicated stream controller.
  //
  // Usage:
  //   final stream = repo.subscribeToChannel(
  //     channel: 'private-school.5',
  //     event:   'BusLocationUpdated',
  //   );
  //   stream.listen((data) => ...);

  /// Map key: '$channel:$event'  →  broadcast StreamController
  final _dynCtrl = <String, StreamController<Map<String, dynamic>>>{};

  /// Returns a broadcast stream of event payloads for [channel]/[event].
  /// Subscribes to the Pusher channel on first listener.
  Stream<Map<String, dynamic>> subscribeToChannel({
    required String channel,
    required String event,
  }) {
    final key = '$channel:$event';
    if (!_dynCtrl.containsKey(key)) {
      _dynCtrl[key] = StreamController<Map<String, dynamic>>.broadcast(
        onListen: () => _subscribeNamedChannel(channel),
        onCancel: () {
          _dynCtrl.remove(key)?.close();
          _unsubscribeNamedChannel(channel);
        },
      );
    }
    return _dynCtrl[key]!.stream;
  }

  /// Cancel a dynamic subscription explicitly (optional — onCancel handles it).
  void unsubscribeFromChannel({required String channel, required String event}) {
    final key = '$channel:$event';
    _dynCtrl.remove(key)?.close();
    _unsubscribeNamedChannel(channel);
  }

  Future<void> _subscribeNamedChannel(String channel) async {
    if (_socketId == null) return; // not yet connected — resubscribed on connect
    final auth = await _getChannelAuth(channel);
    if (auth == null) {
      debugPrint('[Reverb] ❌ dynamic auth failed for $channel');
      return;
    }
    _send({'event': 'pusher:subscribe', 'data': {'channel': channel, 'auth': auth}});
    debugPrint('[Reverb] → subscribing $channel (dynamic)');
  }

  void _unsubscribeNamedChannel(String channel) {
    _send({'event': 'pusher:unsubscribe', 'data': {'channel': channel}});
    debugPrint('[Reverb] → unsubscribing $channel (dynamic)');
  }

  /// After reconnect, re-subscribe all channels that still have listeners.
  Future<void> _resubscribeDynamicChannels() async {
    final channels = _dynCtrl.keys.map((k) => k.split(':').first).toSet();
    for (final ch in channels) {
      await _subscribeNamedChannel(ch);
    }
  }

  /// Route an inbound event to any matching dynamic stream controller.
  void _routeToDynamic(String channel, String event, Map<String, dynamic> data) {
    final key  = '$channel:$event';
    final ctrl = _dynCtrl[key];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(data);
    }
  }

  // ── Ping / disconnect / reconnect ──────────────────────────────────────

  void _startPing() {
    _pingTimer?.cancel();
    if (!_connected) return;
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_connected) _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[Reverb] send error: $e');
    }
  }

  void _onDisconnected() {
    _connected = false;
    _socketId  = null;
    _pingTimer?.cancel();
    for (final uid in _onlineUsers) {
      if (!_presenceCtrl.isClosed) _presenceCtrl.add({uid: false});
    }
    _onlineUsers.clear();
    debugPrint('[Reverb] 🔌 disconnected');
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final secs = (_reconnectAttempts < 5)
        ? (4 * (1 << _reconnectAttempts)).clamp(4, 60)
        : 60;
    _reconnectAttempts++;
    debugPrint('[Reverb] retry in ${secs}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (!_disposed) _connect();
    });
  }

  Future<void> _closeSocket() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
    _socketId  = null;
  }

  // ── Mark thread read ───────────────────────────────────────────────────

  Future<void> markThreadRead(String threadKey) async {
    try {
      final token = await _getToken?.call() ?? '';
      if (_baseUrl == null || _baseUrl!.isEmpty || token.isEmpty) return;
      await http.post(
        Uri.parse('$_baseUrl/api/messages/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
          'Accept':        'application/json',
        },
        body: jsonEncode({'thread_key': threadKey}),
      );
    } catch (e) {
      debugPrint('[Reverb] markRead error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _seenIds.clear();
    _onlineUsers.clear();
    // Close all dynamic controllers
    for (final ctrl in _dynCtrl.values) {
      if (!ctrl.isClosed) ctrl.close();
    }
    _dynCtrl.clear();
    await _closeSocket();
    if (!_incomingCtrl.isClosed) await _incomingCtrl.close();
    if (!_presenceCtrl.isClosed) await _presenceCtrl.close();
    if (!_readCtrl.isClosed) await _readCtrl.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Map<String, dynamic> _parseData(dynamic data) {
    if (data is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(data) as Map);
      } catch (_) {
        return {};
      }
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int)  return v;
    if (v is num)  return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ── IMessagingRepository ───────────────────────────────────────────────

  @override
  Future<List<ChatThread>> getInbox() => _datasource.fetchInbox();

  @override
  Future<({List<ChatMessage> messages, bool hasMore})> getThread(
    String threadKey, {
    int page = 1,
  }) =>
      _datasource.fetchThread(threadKey, page: page);

  @override
  Future<ChatMessage> sendDirect({
    required int recipientId,
    required String recipientRole,
    required String body,
    Map<String, dynamic>? meta,
  }) =>
      _datasource.sendDirect(
        recipientId:   recipientId,
        recipientRole: recipientRole,
        body:          body,
        meta:          meta,
      );

  @override
  Future<({ChatMessage message, int recipientsCount})> sendGroup({
    required String groupType,
    required int scopeId,
    required String body,
    Map<String, dynamic>? meta,
  }) =>
      _datasource.sendGroup(
        groupType: groupType,
        scopeId:   scopeId,
        body:      body,
        meta:      meta,
      );
}