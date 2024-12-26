/// Interface for AI service functionality
abstract class IAIService {
  /// Get AI response for a given message
  Future<String> getResponse(String message);

  /// Analyze sentiment/emotions in the text
  Future<Map<String, double>> analyzeEmotions(String text);

  /// Generate a summary of the conversation
  Future<String> generateSummary(List<String> messages);
}
