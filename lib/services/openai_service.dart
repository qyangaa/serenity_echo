import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'interfaces/ai_service_interface.dart';

class OpenAIService implements IAIService {
  final String apiKey;
  final String model;
  final http.Client _client;
  static const String _baseUrl = 'https://api.openai.com/v1';

  OpenAIService({
    required this.apiKey,
    this.model = 'gpt-4',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  @override
  Future<String> getResponse(
    String userInput, {
    String? conversationSummary,
    List<ChatMessage>? recentMessages,
  }) async {
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              '''You are a supportive and empathetic AI journaling companion. 
Help users process their thoughts and feelings while maintaining a warm, understanding tone.
You have access to recent messages and a summary of the conversation history.
When users ask about previous conversations or your memory, refer to this context to provide accurate responses.
Always acknowledge your ability to reference previous parts of the conversation when relevant.''',
        },
      ];

      // Add conversation summary if available
      if (conversationSummary != null) {
        messages.add({
          'role': 'system',
          'content': '''Previous conversation summary: $conversationSummary
When referring to this history, mention that this is from our earlier conversation today.''',
        });
      }

      // Add recent messages for immediate context
      if (recentMessages != null && recentMessages.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': '''Recent conversation context:
${recentMessages.map((m) => "${m.isUser ? "User" : "Assistant"}: ${m.content}").join("\n")}
Use this recent context to maintain conversation continuity.''',
        });
      }

      // Add current user input
      messages.add({
        'role': 'user',
        'content': userInput,
      });

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 250, // Increased to allow for more detailed responses
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting AI response: $e');
      }
      return 'I apologize, but I encountered an error. Could you please try rephrasing your message?';
    }
  }

  @override
  Future<String> generateSummary(List<String> messages) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Analyze the following journal entries and provide a concise, insightful summary that captures the main themes, emotions, and patterns.',
            },
            {
              'role': 'user',
              'content': messages.join('\n'),
            },
          ],
          'temperature': 0.5,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to generate summary: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating summary: $e');
      }
      return 'Unable to generate summary at this time.';
    }
  }

  @override
  Future<Map<String, double>> analyzeEmotion(String message) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Analyze the emotional content of the following text and return a JSON object with emotion scores (0-1) for: joy, sadness, anger, fear, surprise, and love.',
            },
            {
              'role': 'user',
              'content': message,
            },
          ],
          'temperature': 0.3,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final emotionJson = data['choices'][0]['message']['content'];
        final emotions = jsonDecode(emotionJson) as Map<String, dynamic>;
        return emotions.map((key, value) => MapEntry(key, value.toDouble()));
      } else {
        throw Exception('Failed to analyze emotions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing emotions: $e');
      }
      return {
        'joy': 0.0,
        'sadness': 0.0,
        'anger': 0.0,
        'fear': 0.0,
        'surprise': 0.0,
        'love': 0.0,
      };
    }
  }

  @override
  Future<List<String>> generateFollowUpQuestions(
      List<ChatMessage> conversation) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Based on the conversation, generate 3 thoughtful follow-up questions that would help the user explore their thoughts and feelings more deeply. Return only the questions, one per line.',
            },
            {
              'role': 'user',
              'content': conversation
                  .map((m) => '${m.isUser ? "User" : "AI"}: ${m.content}')
                  .join('\n'),
            },
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        final questions = content
            .split('\n')
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty)
            .toList();
        return questions;
      } else {
        throw Exception(
            'Failed to generate follow-up questions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating follow-up questions: $e');
      }
      return [
        'Would you like to tell me more about that?',
        'How did that make you feel?',
        'What do you think about this now?',
      ];
    }
  }

  @override
  Future<String> generateReflectionPrompt(
      List<ChatMessage> todaysMessages) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Based on today\'s journal entries, generate a thoughtful reflection prompt that would help the user gain deeper insights.',
            },
            {
              'role': 'user',
              'content': todaysMessages
                  .map((m) => '${m.isUser ? "User" : "AI"}: ${m.content}')
                  .join('\n'),
            },
          ],
          'temperature': 0.7,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception(
            'Failed to generate reflection prompt: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating reflection prompt: $e');
      }
      return 'What was the most meaningful part of your day, and why?';
    }
  }

  @override
  Future<bool> moderateContent(String content) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/moderations'),
        headers: _headers,
        body: jsonEncode({
          'input': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return !data['results'][0]['flagged'];
      } else {
        throw Exception('Failed to moderate content: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error moderating content: $e');
      }
      // Default to true if moderation fails to avoid blocking user input
      return true;
    }
  }

  void dispose() {
    _client.close();
  }
}
