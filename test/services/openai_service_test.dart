import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/models/chat_message.dart';
import 'package:serenity_echo/services/openai_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late OpenAIService openAIService;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.openai.com/v1/test'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    openAIService = OpenAIService(
      apiKey: 'test_api_key',
      client: mockHttpClient,
    );
  });

  group('OpenAIService', () {
    test('getResponse returns AI response for user input', () async {
      // Arrange
      const expectedResponse = 'This is a test response';
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': expectedResponse}
                }
              ]
            }),
            200,
          ));

      // Act
      final response = await openAIService.getResponse('Hello');

      // Assert
      expect(response, expectedResponse);
      verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: contains('"content":"Hello"'),
          )).called(1);
    });

    test('generateSummary returns summary of messages', () async {
      // Arrange
      const expectedSummary = 'Summary of the conversation';
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': expectedSummary}
                }
              ]
            }),
            200,
          ));

      // Act
      final summary =
          await openAIService.generateSummary(['Message 1', 'Message 2']);

      // Assert
      expect(summary, expectedSummary);
    });

    test('analyzeEmotion returns emotion scores', () async {
      // Arrange
      final expectedEmotions = {
        'joy': 0.8,
        'sadness': 0.2,
        'anger': 0.1,
        'fear': 0.1,
        'surprise': 0.3,
        'love': 0.7,
      };
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': jsonEncode(expectedEmotions)}
                }
              ]
            }),
            200,
          ));

      // Act
      final emotions = await openAIService.analyzeEmotion('I am happy');

      // Assert
      expect(emotions, expectedEmotions);
    });

    test('generateFollowUpQuestions returns list of questions', () async {
      // Arrange
      final expectedQuestions = [
        'How did that make you feel?',
        'What do you think about it now?',
        'Would you do anything differently?'
      ];

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': expectedQuestions.join('\n')}
                }
              ]
            }),
            200,
          ));

      // Act
      final questions = await openAIService.generateFollowUpQuestions([
        ChatMessage(
          content: 'Test message',
          isUser: true,
          id: 'test-id-1',
          timestamp: DateTime.now(),
        ),
      ]);

      // Assert
      expect(questions, equals(expectedQuestions));

      verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    test('generateReflectionPrompt returns a reflection prompt', () async {
      // Arrange
      const expectedPrompt = 'What was the most challenging part of your day?';
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': expectedPrompt}
                }
              ]
            }),
            200,
          ));

      // Act
      final prompt = await openAIService.generateReflectionPrompt([
        ChatMessage(
          content: 'Test message',
          isUser: true,
          id: 'test-id-2',
          timestamp: DateTime.now(),
        ),
      ]);

      // Assert
      expect(prompt, expectedPrompt);
    });

    test('moderateContent returns true for safe content', () async {
      // Arrange
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'results': [
                {'flagged': false}
              ]
            }),
            200,
          ));

      // Act
      final isSafe = await openAIService.moderateContent('Safe content');

      // Assert
      expect(isSafe, true);
    });

    test('handles API errors gracefully', () async {
      // Arrange
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      // Act & Assert
      final response = await openAIService.getResponse('Hello');
      expect(response, contains('I apologize'));
    });
  });
}
