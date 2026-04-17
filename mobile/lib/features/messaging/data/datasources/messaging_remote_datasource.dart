// SAVE AS: lib/features/messaging/data/datasources/messaging_remote_datasource.dart

import '../../../../services/api_service.dart';
import '../../../../config/api_config.dart';
import '../../domain/entities/message_entities.dart';
import '../models/message_models.dart';

Map<String, dynamic> _toMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

List<Map<String, dynamic>> _toMapList(dynamic v) {
  if (v is List) return v.whereType<Map>().map(_toMap).toList();
  if (v is Map)  return [_toMap(v)];
  return [];
}

class MessagingRemoteDatasource {
  const MessagingRemoteDatasource();

  // ── Inbox ─────────────────────────────────────────────────────────────────

  Future<List<ChatThread>> fetchInbox() async {
    final raw = await ApiService.get(ApiConfig.messagesInbox);

    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      final threads = raw['threads'] ?? raw['data'] ?? [];
      list = threads is List ? threads : [threads];
    } else {
      list = [];
    }

    return _toMapList(list).map(ChatThreadModel.fromJson).toList();
  }

  // ── Thread ────────────────────────────────────────────────────────────────

  Future<({List<ChatMessage> messages, bool hasMore})> fetchThread(
    String threadKey, {
    int page = 1,
  }) async {
    final raw = await ApiService.get(
      ApiConfig.messagesThread(threadKey),
      queryParams: {'page': page},
    );

    final List<Map<String, dynamic>> items;
    final bool hasMore;

    if (raw is List) {
      items   = _toMapList(raw);
      hasMore = false;
    } else if (raw is Map) {
      final dataField = raw['data'];
      if (dataField is List) {
        items   = _toMapList(dataField);
        hasMore = raw['next_page_url'] != null;
      } else if (dataField is Map) {
        items   = [_toMap(dataField)];
        hasMore = false;
      } else if (dataField == null) {
        items   = raw.containsKey('body') ? [_toMap(raw)] : [];
        hasMore = false;
      } else {
        items   = [];
        hasMore = false;
      }
    } else {
      items   = [];
      hasMore = false;
    }

    // Guard: skip any item missing body (can't display) — id handled by _int()
    final messages = items
        .where((m) => m['body'] != null)
        .map(ChatMessageModel.fromJson)
        .toList()
        .reversed
        .toList();

    return (messages: messages, hasMore: hasMore);
  }

  // ── Send direct ───────────────────────────────────────────────────────────

  Future<ChatMessage> sendDirect({
    required int recipientId,
    required String recipientRole,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    final raw = await ApiService.post(
      ApiConfig.messagesDirect,
      body: {
        'recipient_id':   recipientId,
        'recipient_role': recipientRole,
        'body':           body,
        if (meta != null) 'meta': meta,
      },
    );

    // Unwrap {"message": {...}} or use root map directly
    final data   = _toMap(raw);
    final msgMap = data.containsKey('message') && data['message'] is Map
        ? _toMap(data['message'])
        : data;

    // Guarantee body is present — fallback to the sent body if API echoes wrong shape
    if (msgMap['body'] == null) msgMap['body'] = body;

    return ChatMessageModel.fromJson(msgMap);
  }

  // ── Send group ────────────────────────────────────────────────────────────

  Future<({ChatMessage message, int recipientsCount})> sendGroup({
    required String groupType,
    required int scopeId,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    final raw = await ApiService.post(
      ApiConfig.messagesGroup,
      body: {
        'group_type': groupType,
        'scope_id':   scopeId,
        'body':       body,
        if (meta != null) 'meta': meta,
      },
    );

    final data   = _toMap(raw);
    final msgMap = _toMap(data['message'] ?? data);

    if (msgMap['body'] == null) msgMap['body'] = body;

    return (
      message:         ChatMessageModel.fromJson(msgMap),
      recipientsCount: (data['recipients_count'] as num?)?.toInt() ?? 0,
    );
  }
}