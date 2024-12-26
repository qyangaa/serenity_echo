import '../../models/chat_message.dart';

/// Interface for AI service functionality
abstract class IAIService {
  /// Get a response from the AI based on user input
  Future<String> getResponse(String userInput);

  /// Generate a summary of the chat history
  Future<String> generateSummary(List<String> messages);

  /// Get emotional analysis of the message
  Future<Map<String, double>> analyzeEmotion(String message);

  /// Generate follow-up questions based on the conversation
  Future<List<String>> generateFollowUpQuestions(
      List<ChatMessage> conversation);

  /// Generate a daily reflection prompt based on chat history
  Future<String> generateReflectionPrompt(List<ChatMessage> todaysMessages);

  /// Check if the content is safe and appropriate
  Future<bool> moderateContent(String content);
}
