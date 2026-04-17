// SAVE AS: lib/features/messaging/domain/entities/message_entities.dart

// ── Message delivery status (WhatsApp style) ──────────────────────────────────
enum MessageStatus {
  sending,    // optimistic — clock icon
  sent,       // 1 grey tick  — server received
  delivered,  // 2 grey ticks — recipient device received
  read,       // 2 blue ticks — recipient opened thread
  failed,     // red X
}

// ── Thread ────────────────────────────────────────────────────────────────────

class ChatThread {
  final String threadKey;
  final String threadType;
  final String label;
  final String? sublabel;
  final String? avatarLabel;
  final String? avatarColor;
  final String? photo;
  final int? memberCount;
  final String? lastMessage;
  final DateTime? lastTime;
  final int unreadCount;
  final String? senderRole;
  final String? senderName;
  final bool isOnline;          // recipient is currently connected to Reverb
  final Map<String, dynamic> meta;

  const ChatThread({
    required this.threadKey,
    required this.threadType,
    required this.label,
    this.sublabel,
    this.avatarLabel,
    this.avatarColor,
    this.photo,
    this.memberCount,
    this.lastMessage,
    this.lastTime,
    this.unreadCount = 0,
    this.senderRole,
    this.senderName,
    this.isOnline   = false,
    this.meta       = const {},
  });

  bool get isGroup   => threadType == 'group';
  bool get hasUnread => unreadCount > 0;

  int?    get recipientId   => meta['recipient_id']   as int?;
  String? get recipientRole => meta['recipient_role'] as String?;
  String? get childName     => meta['child_name']     as String?;
  bool    get hasBoarded    => (meta['has_boarded']   as bool?) ?? false;
  String? get groupType     => meta['group_type']     as String?;
  int?    get scopeId       => meta['scope_id']       as int?;
  int?    get tripId        => meta['trip_id']        as int?;
  int?    get boardedCount  => meta['boarded_count']  as int?;
  int?    get totalCount    => meta['total_count']    as int?;
}

// ── Message ───────────────────────────────────────────────────────────────────

class ChatMessage {
  final int id;
  final String threadKey;
  final int senderId;
  final String senderName;
  final String senderRole;
  final String body;
  final Map<String, dynamic>? meta;
  final bool isBroadcast;
  final DateTime at;
  final MessageStatus status;   // delivery/read status

  const ChatMessage({
    required this.id,
    required this.threadKey,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    this.meta,
    this.isBroadcast = false,
    required this.at,
    this.status = MessageStatus.sent,
  });

  String? get alertCategory => meta?['alert_category'] as String?;

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
    id:          id,
    threadKey:   threadKey,
    senderId:    senderId,
    senderName:  senderName,
    senderRole:  senderRole,
    body:        body,
    meta:        meta,
    isBroadcast: isBroadcast,
    at:          at,
    status:      status ?? this.status,
  );
}

// ── Incoming popup ────────────────────────────────────────────────────────────

class IncomingMessage {
  final ChatMessage message;
  final String threadLabel;
  final String? childName;

  const IncomingMessage({
    required this.message,
    required this.threadLabel,
    this.childName,
  });
}