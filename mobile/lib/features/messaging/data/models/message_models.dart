// SAVE AS: lib/features/messaging/data/models/message_models.dart

import '../../domain/entities/message_entities.dart';

Map<String, dynamic> _m(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

/// Safely converts any JSON number to int.
/// On web, JSON numbers sometimes arrive as double.
/// Returns [fallback] when value is null or unparseable.
int _int(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

extension ChatThreadModel on ChatThread {
  static ChatThread fromJson(Map<String, dynamic> j) => ChatThread(
        threadKey:   j['thread_key']  as String,
        threadType:  j['thread_type'] as String? ?? 'direct',
        label:       j['label']       as String,
        sublabel:    j['sublabel']    as String?,
        avatarLabel: j['avatar_label'] as String?,
        avatarColor: j['avatar_color'] as String?,
        photo:       j['photo']       as String?,
        memberCount: j['member_count'] == null ? null : _int(j['member_count']),
        lastMessage: j['last_message'] as String?,
        lastTime:    j['last_time'] != null
            ? DateTime.tryParse(j['last_time'] as String)
            : null,
        unreadCount: _int(j['unread_count']),
        senderRole:  j['sender_role'] as String?,
        senderName:  j['sender_name'] as String?,
        meta:        j['meta'] != null ? _m(j['meta']) : const {},
      );
}

extension ChatMessageModel on ChatMessage {
  static ChatMessage fromJson(Map<String, dynamic> j) => ChatMessage(
        // _int() never throws — handles null, double, and String variants
        id:          _int(j['id'], fallback: -(DateTime.now().millisecondsSinceEpoch)),
        threadKey:   j['thread_key']  as String? ?? '',
        senderId:    _int(j['sender_id']),
        senderName:  j['sender_name'] as String? ?? '',
        senderRole:  j['sender_role'] as String? ?? '',
        body:        j['body']        as String? ?? '',
        meta:        j['meta'] != null ? _m(j['meta']) : null,
        isBroadcast: (j['is_broadcast'] as bool?) ?? false,
        at:          j['at'] != null
            ? (DateTime.tryParse(j['at'] as String) ?? DateTime.now())
            : DateTime.now(),
      );

  static ChatMessage fromPusher(Map<String, dynamic> j) => fromJson(j);
}