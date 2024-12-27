import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';
import '../../models/emotion_analysis.dart';

/// Interface for chat service functionality
abstract class IChatService extends ChangeNotifier {
  /// List of all chat messages
  List<ChatMessage> get messages;

  /// Add a new user message and get AI response
  Future<void> addUserMessage(String content);

  /// Clear all chat messages and create a new session
  Future<void> clearChat();

  /// Generate follow-up questions based on the current conversation
  Future<List<String>> generateFollowUpQuestions();

  /// Analyze emotions in a message
  Future<EmotionAnalysis> analyzeEmotions(String message);

  /// Generate a reflection prompt based on the current conversation
  Future<String> generateReflectionPrompt();
}
