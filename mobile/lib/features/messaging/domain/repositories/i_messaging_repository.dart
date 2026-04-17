// SAVE AS: lib/features/messaging/domain/repositories/i_messaging_repository.dart

import '../entities/message_entities.dart';

abstract interface class IMessagingRepository {
  Future<List<ChatThread>> getInbox();

  Future<({List<ChatMessage> messages, bool hasMore})> getThread(
    String threadKey, {
    int page = 1,
  });

  Future<ChatMessage> sendDirect({
    required int recipientId,
    required String recipientRole,
    required String body,
    Map<String, dynamic>? meta,
  });

  Future<({ChatMessage message, int recipientsCount})> sendGroup({
    required String groupType,
    required int scopeId,
    required String body,
    Map<String, dynamic>? meta,
  });

  // ✅ ADD THESE ↓↓↓
  Future<void> init();
  Future<void> dispose();
  set userId(int id);
}