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
  Future<String> getResponse(String userInput) async {
    try {
      if (kDebugMode) {
        print('\n=== AI Response Request ===');
        print('User Input: $userInput');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a supportive and empathetic AI journaling companion. Help users process their thoughts and feelings while maintaining a warm, understanding tone.',
            },
            {
              'role': 'user',
              'content': userInput,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        if (kDebugMode) {
          print('AI Response: $aiResponse');
          print('=========================\n');
        }
        return aiResponse;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting AI response: $e');
        print('=========================\n');
      }
      return 'I apologize, but I encountered an error. Could you please try rephrasing your message?';
    }
  }

  @override
  Future<String> generateSummary(List<String> messages) async {
    try {
      if (kDebugMode) {
        print('\n=== Summary Generation Request ===');
        print('Number of messages to summarize: ${messages.length}');
        print('\nLast 3 messages for context:');
        messages.reversed
            .take(3)
            .toList()
            .reversed
            .forEach((m) => print('- $m'));
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  '''Analyze the journal entries and provide a structured summary in markdown format:

## Key Topics
- [List 2-3 main topics or themes discussed]

## Emotional State
- [List 2-3 primary emotions expressed]
- [Note any significant emotional shifts]

## Insights & Growth
- [List 1-2 key realizations or learnings]
- [Note any personal growth or progress]

## Action Items
- [List 1-2 potential next steps or intentions mentioned]

Keep each bullet point concise (1-2 lines). Use the exact markdown format above with headers and bullet points.''',
            },
            {
              'role': 'user',
              'content': messages.join('\n'),
            },
          ],
          'temperature': 0.5,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['choices'][0]['message']['content'];
        if (kDebugMode) {
          print('\nAPI Response Status: ${response.statusCode}');
          print('\nGenerated Summary:');
          print('----------------------------------------');
          print(summary);
          print('----------------------------------------');
          print('\nSummary Statistics:');
          print('- Length: ${summary.length} characters');
          print('- Sections: ${summary.split('##').length - 1} sections');
          print('- Bullet points: ${summary.split('-').length - 1} points');
          print('===============================\n');
        }
        return summary;
      } else {
        throw Exception('Failed to generate summary: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating summary: $e');
        print('===============================\n');
      }
      return '''## Key Topics
- Unable to generate summary at this time

## Emotional State
- System error occurred

## Insights & Growth
- Please try again later

## Action Items
- Refresh the app and try again''';
    }
  }

  @override
  Future<Map<String, double>> analyzeEmotion(String message) async {
    try {
      if (kDebugMode) {
        print('\n=== Emotion Analysis Request ===');
        print('Message to analyze: $message');
      }

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
        final emotionScores = emotions.map((key, value) =>
            MapEntry(key, (value is num) ? value.toDouble() : 0.0));
        if (kDebugMode) {
          print('\nEmotion Scores:');
          emotionScores.forEach((emotion, score) => print('$emotion: $score'));
          print('============================\n');
        }
        return emotionScores;
      } else {
        throw Exception('Failed to analyze emotions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing emotions: $e');
        print('============================\n');
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
      if (kDebugMode) {
        print('\n=== Follow-up Questions Request ===');
        print('Conversation context:');
        for (var m in conversation) {
          print('${m.isUser ? "User" : "AI"}: ${m.content}');
        }
      }

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
        if (kDebugMode) {
          print('\nGenerated Questions:');
          for (var q in questions) {
            print('- $q');
          }
          print('================================\n');
        }
        return questions;
      } else {
        throw Exception(
            'Failed to generate follow-up questions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating follow-up questions: $e');
        print('================================\n');
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
