// lib/features/messaging/presentation/providers/messaging_providers.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message_entities.dart';
import '../../data/repositories/messaging_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER — singleton repository
//
// FIX 1: Changed from Provider<IMessagingRepository> to
//         Provider<MessagingRepository> so every cast is type-safe and
//         streams (incomingStream, presenceStream, readReceiptStream) are
//         always accessible without a nullable cast that silently returns null.
// ─────────────────────────────────────────────────────────────────────────────

final messagingRepoProvider = Provider<MessagingRepository>((ref) {
  throw UnimplementedError('Override messagingRepoProvider in ProviderScope');
});

// ─────────────────────────────────────────────────────────────────────────────
// INBOX
// ─────────────────────────────────────────────────────────────────────────────

class InboxState {
  final List<ChatThread> threads;
  final bool loading;
  final String? error;

  const InboxState({
    this.threads = const [],
    this.loading = false,
    this.error,
  });

  InboxState copyWith({
    List<ChatThread>? threads,
    bool? loading,
    String? error,
  }) =>
      InboxState(
        threads: threads ?? this.threads,
        loading: loading ?? this.loading,
        error: error,
      );
}

class InboxNotifier extends StateNotifier<InboxState> {
  final MessagingRepository _repo;
  StreamSubscription<ChatMessage>? _sub;
  Timer? _debounce;

  InboxNotifier(this._repo) : super(const InboxState()) {
    fetch();

    // FIX 2: Direct typed access — no nullable cast needed anymore.
    // Debounced so rapid incoming messages don't flood the API.
    _sub = _repo.incomingStream.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), fetch);
    });
  }

  Future<void> fetch() async {
    if (!mounted) return;
    if (state.threads.isEmpty) state = state.copyWith(loading: true);
    try {
      final threads = await _repo.getInbox();
      if (mounted) {
        state = state.copyWith(threads: threads, loading: false, error: null);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(loading: false, error: e.toString());
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THREAD
// ─────────────────────────────────────────────────────────────────────────────

class ThreadState {
  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool sending;
  final String? error;
  final Map<int, bool> presence;
  final Set<int> readBy;

  const ThreadState({
    this.messages = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.sending = false,
    this.error,
    this.presence = const {},
    this.readBy = const {},
  });

  ThreadState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? sending,
    String? error,
    Map<int, bool>? presence,
    Set<int>? readBy,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        sending: sending ?? this.sending,
        error: error,
        presence: presence ?? this.presence,
        readBy: readBy ?? this.readBy,
      );
}

class ThreadNotifier extends StateNotifier<ThreadState> {
  final MessagingRepository _repo;
  final String threadKey;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<Map<int, bool>>? _presenceSub;
  StreamSubscription<({String threadKey, int userId})>? _readSub;

  int _page = 1;

  ThreadNotifier(this._repo, this.threadKey) : super(const ThreadState()) {
    fetch();
    _wireStreams();
  }

  void _wireStreams() {
    // ── Incoming messages ──────────────────────────────────────────────────
    // FIX 3: Direct typed stream access. Message appends in O(1) — no fetch.
    _msgSub = _repo.incomingStream.listen((msg) {
      if (!mounted || msg.threadKey != threadKey) return;
      if (state.messages.any((m) => m.id == msg.id)) return; // dedup

      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages,
          msg.copyWith(status: MessageStatus.delivered),
        ],
      );

      // Auto-mark read since user is actively viewing this thread
      _repo.markThreadRead(threadKey);
    });

    // ── Presence ────────────────────────────────────────────────────────────
    _presenceSub = _repo.presenceStream.listen((update) {
      if (!mounted) return;
      state = state.copyWith(presence: {...state.presence, ...update});
    });

    // ── Read receipts → blue ticks ──────────────────────────────────────────
    _readSub = _repo.readReceiptStream.listen((event) {
      if (!mounted || event.threadKey != threadKey) return;
      final updated = state.messages.map((m) {
        if (m.status == MessageStatus.sent ||
            m.status == MessageStatus.delivered) {
          return m.copyWith(status: MessageStatus.read);
        }
        return m;
      }).toList();
      state = state.copyWith(
        messages: updated,
        readBy: {...state.readBy, event.userId},
      );
    });

    // ── Seed presence from current online snapshot ──────────────────────────
    // FIX 4: _parseRecipientId now correctly excludes the current user's own
    // id, so we seed the OTHER person's presence, not our own.
    final recipientId = _parseRecipientId(threadKey);
    if (recipientId != null) {
      state = state.copyWith(
        presence: {recipientId: _repo.isUserOnline(recipientId)},
      );
    }
  }

  /// Returns the OTHER participant's id from a direct thread key.
  ///
  /// Thread key format: "role_id__role_id"  (alphabetically sorted)
  /// e.g. "admin_2__driver_4"
  ///
  /// FIX 4: Previous version returned the FIRST id found, which could be
  /// the current user's own id when the key starts with their segment.
  /// Now we parse BOTH ids and return the one that isn't _repo.userId.
  int? _parseRecipientId(String key) {
    if (key.startsWith('group_')) return null;
    final parts = key.split('__');
    if (parts.length != 2) return null;

    for (final part in parts) {
      final segments = part.split('_');
      final id = int.tryParse(segments.last);
      if (id != null && id != _repo.userId) return id;
    }
    return null;
  }

  Future<void> fetch() async {
    _page = 1;
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.getThread(threadKey, page: 1);
      if (mounted) {
        state = state.copyWith(
          messages: result.messages,
          hasMore: result.hasMore,
          loading: false,
        );
      }
      // Mark read — triggers blue ticks on sender's side
      _repo.markThreadRead(threadKey);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(loading: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      _page++;
      final result = await _repo.getThread(threadKey, page: _page);
      if (mounted) {
        state = state.copyWith(
          messages: <ChatMessage>[...result.messages, ...state.messages],
          hasMore: result.hasMore,
          loadingMore: false,
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> sendDirect({
    required int recipientId,
    required String recipientRole,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final optimistic = ChatMessage(
      id: tempId,
      threadKey: threadKey,
      senderId: _repo.userId, // FIX 5: use actual userId, not hardcoded 0
      senderName: 'You',
      senderRole: '',
      body: body,
      at: DateTime.now(),
      status: MessageStatus.sending,
    );

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, optimistic],
      sending: true,
    );

    try {
      final msg = await _repo.sendDirect(
        recipientId: recipientId,
        recipientRole: recipientRole,
        body: body,
        meta: meta,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages.where((m) => m.id != tempId),
          msg.copyWith(status: MessageStatus.sent),
        ],
        sending: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .map((m) =>
                m.id == tempId ? m.copyWith(status: MessageStatus.failed) : m)
            .toList(),
        sending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendGroup({
    required String groupType,
    required int scopeId,
    required String body,
    Map<String, dynamic>? meta,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final optimistic = ChatMessage(
      id: tempId,
      threadKey: threadKey,
      senderId: _repo.userId, // FIX 5: use actual userId
      senderName: 'You',
      senderRole: '',
      body: body,
      at: DateTime.now(),
      status: MessageStatus.sending,
    );

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, optimistic],
      sending: true,
    );

    try {
      final result = await _repo.sendGroup(
        groupType: groupType,
        scopeId: scopeId,
        body: body,
        meta: meta,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: <ChatMessage>[
          ...state.messages.where((m) => m.id != tempId),
          result.message.copyWith(status: MessageStatus.sent),
        ],
        sending: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .map((m) =>
                m.id == tempId ? m.copyWith(status: MessageStatus.failed) : m)
            .toList(),
        sending: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _presenceSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INCOMING POPUP
// ─────────────────────────────────────────────────────────────────────────────

class IncomingPopupNotifier extends StateNotifier<IncomingMessage?> {
  final MessagingRepository _repo;
  StreamSubscription<ChatMessage>? _sub;
  Timer? _timer;

  // FIX 6: Track which thread the user is currently viewing so we suppress
  // popups for messages in the active thread.
  String? _activeThreadKey;

  IncomingPopupNotifier(this._repo) : super(null) {
    // FIX 3: Direct typed stream — no nullable cast.
    _sub = _repo.incomingStream.listen((msg) {
      if (!mounted) return;

      // Suppress if the user is already in this thread
      if (msg.threadKey == _activeThreadKey) return;

      state = IncomingMessage(
        message: msg,
        threadLabel: _label(msg.threadKey),
      );
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) state = null;
      });
    });
  }

  /// Call from ChatScreen.initState to suppress popups for the open thread.
  void setActiveThread(String? key) => _activeThreadKey = key;

  void dismiss() {
    if (mounted) state = null;
  }

  String _label(String key) {
    if (key.startsWith('group_parents_trip')) return 'Group · Parents';
    if (key.startsWith('group_drivers_school')) return 'Group · Drivers';
    if (key.startsWith('group_admins')) return 'Group · Admins';
    if (key.contains('parent')) return 'Parent Message';
    if (key.contains('driver')) return 'Driver Message';
    if (key.contains('admin')) return 'Admin Message';
    return 'New Message';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

// FIX 7: Removed .autoDispose from inboxProvider and threadProvider.
//
// autoDispose destroys the StateNotifier (and its stream subscriptions) the
// moment no widget is watching it — i.e. when you navigate away. That means:
//   • InboxNotifier._sub is cancelled → inbox stops updating in background
//   • ThreadNotifier._msgSub is cancelled → messages are lost until refresh
//
// Without autoDispose the notifiers stay alive for the app session, which is
// exactly what we want for a persistent chat experience.

final inboxProvider = StateNotifierProvider<InboxNotifier, InboxState>(
  (ref) => InboxNotifier(ref.watch(messagingRepoProvider)),
);

final threadProvider =
    StateNotifierProvider.family<ThreadNotifier, ThreadState, String>(
  (ref, key) => ThreadNotifier(ref.watch(messagingRepoProvider), key),
);

// incomingPopupProvider intentionally has no autoDispose — it must survive
// navigation to show popups from any screen.
final incomingPopupProvider =
    StateNotifierProvider<IncomingPopupNotifier, IncomingMessage?>(
  (ref) => IncomingPopupNotifier(ref.watch(messagingRepoProvider)),
);

final totalUnreadProvider = Provider.autoDispose<int>(
  (ref) => ref
      .watch(inboxProvider.select((s) => s.threads))
      .fold(0, (sum, t) => sum + t.unreadCount),
);