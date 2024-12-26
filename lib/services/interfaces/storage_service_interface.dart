import '../../models/chat_message.dart';

/// Interface for storage service functionality
abstract class IStorageService {
  /// Save a chat session
  Future<void> saveChatSession(List<ChatMessage> messages);

  /// Load chat sessions
  Future<List<ChatMessage>> loadChatSessions();

  /// Delete a chat session
  Future<void> deleteChatSession(String sessionId);
}
