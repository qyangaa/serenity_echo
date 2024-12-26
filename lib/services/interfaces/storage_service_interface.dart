import '../../models/chat_session.dart';

/// Interface for storage service functionality
abstract class IStorageService {
  /// Save or update a chat session
  Future<void> saveChatSession(ChatSession session);

  /// Load the most recent chat session
  Future<ChatSession?> loadCurrentSession();

  /// Load all chat sessions
  Future<List<ChatSession>> loadAllSessions();

  /// Delete a chat session
  Future<void> deleteSession(String sessionId);

  /// Update session summary
  Future<void> updateSessionSummary(String sessionId, String summary);
}
