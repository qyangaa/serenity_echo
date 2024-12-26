import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';

/// Interface for chat service functionality
abstract class IChatService extends ChangeNotifier {
  /// List of all chat messages
  List<ChatMessage> get messages;

  /// Add a new user message and get AI response
  Future<void> addUserMessage(String content);

  /// Clear all chat messages and create a new session
  Future<void> clearChat();
}
