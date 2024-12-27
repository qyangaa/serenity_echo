import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/models/chat_message.dart';
import 'package:serenity_echo/models/chat_session.dart';
import 'package:serenity_echo/services/chat_service.dart';
import '../mocks/mock_ai_service.dart';
import '../mocks/mock_storage_service.dart';
import '../mocks/mock_chat_session.dart';

void main() {
  late ChatService chatService;
  late MockAIService mockAIService;
  late MockStorageService mockStorageService;
  late ChatSession mockSession;

  setUpAll(() {
    registerFallbackValue(ChatSessionFake());
  });

  setUp(() {
    mockAIService = MockAIService();
    mockStorageService = MockStorageService();

    // Create a mock session
    mockSession = ChatSession(
      id: 'test_session_id',
      messages: [],
      messageCount: 0,
      created: DateTime.now(),
      updated: DateTime.now(),
    );

    // Set up default mock responses
    when(() => mockAIService.moderateContent(any()))
        .thenAnswer((_) async => true);
    when(() => mockAIService.getResponse(
          any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'),
        )).thenAnswer((_) async => "Mock AI Response");
    when(() => mockAIService.generateSummary(any()))
        .thenAnswer((_) async => "Mock Summary");
    when(() => mockStorageService.loadCurrentSession())
        .thenAnswer((_) async => mockSession);
    when(() => mockStorageService.saveChatSession(any()))
        .thenAnswer((_) async => {});
    when(() => mockStorageService.updateSessionSummary(any(), any()))
        .thenAnswer((_) async => {});

    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );
  });

  group('ChatService Session Management', () {
    test('should load existing session on initialization', () async {
      // Verify that loadCurrentSession was called during initialization
      verify(() => mockStorageService.loadCurrentSession()).called(1);
    });

    test('should create new session if none exists', () async {
      // Setup mock sequence
      var callCount = 0;
      when(() => mockStorageService.loadCurrentSession()).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? null : mockSession;
      });

      // Create new instance to trigger initialization
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Wait for initialization
      await Future.delayed(Duration.zero);

      // Verify session creation attempt
      verify(() => mockStorageService.saveChatSession(any())).called(1);
      verify(() => mockStorageService.loadCurrentSession())
          .called(greaterThan(1));
    });

    test('should reuse existing session for the day', () async {
      final message1 = 'First message';
      final message2 = 'Second message';

      await chatService.addUserMessage(message1);
      await chatService.addUserMessage(message2);

      // Verify that we're using the same session
      verify(() => mockStorageService.saveChatSession(any())).called(2);
      verify(() => mockStorageService.loadCurrentSession()).called(1);
    });
  });

  group('ChatService Message Handling', () {
    test('should add user message and get AI response', () async {
      const userMessage = 'Hello';
      const aiResponse = 'Hi there!';

      when(() => mockAIService.getResponse(
            userMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).thenAnswer((_) async => aiResponse);

      await chatService.addUserMessage(userMessage);

      expect(chatService.messages.length, equals(2));
      expect(chatService.messages[0].content, equals(userMessage));
      expect(chatService.messages[0].isUser, isTrue);
      expect(chatService.messages[1].content, equals(aiResponse));
      expect(chatService.messages[1].isUser, isFalse);
    });

    test('should generate summary after reaching message threshold', () async {
      var summaryGenerationCount = 0;
      var summaryUpdateCount = 0;

      // Track summary generation and updates
      when(() => mockAIService.generateSummary(any())).thenAnswer((_) {
        summaryGenerationCount++;
        return Future.value("Mock Summary");
      });
      when(() => mockStorageService.updateSessionSummary(any(), any()))
          .thenAnswer((_) {
        summaryUpdateCount++;
        return Future.value();
      });

      // Add messages up to just before the threshold (6 messages = 3 user + 3 AI)
      await chatService.addUserMessage('Message 1');
      await chatService.addUserMessage('Message 2');
      await chatService.addUserMessage('Message 3');
      expect(summaryGenerationCount, equals(0),
          reason: 'Summary should not be generated yet');

      // Add one more message to trigger summary (8 messages = 4 user + 4 AI)
      await chatService.addUserMessage('Message 4');
      await Future.delayed(
          const Duration(milliseconds: 100)); // Wait for async operations

      // Verify summary was generated and saved
      expect(summaryGenerationCount, equals(1),
          reason: 'Summary should be generated exactly once');
      expect(summaryUpdateCount, equals(1),
          reason: 'Summary should be updated exactly once');

      // Add another message to verify summary isn't generated again
      await chatService.addUserMessage('Message 5');
      await Future.delayed(
          const Duration(milliseconds: 100)); // Wait for async operations
      expect(summaryGenerationCount, equals(1),
          reason: 'Summary should not be generated again');
    });

    test('should not generate summary if last summary is too recent', () async {
      // Setup mock session with recent summary
      mockSession = mockSession.copyWith(
        historySummary: 'Recent summary',
        lastSummarized: DateTime.now(),
      );

      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      // Create new instance with updated mock
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Add enough messages to normally trigger summary
      for (var i = 0; i < 8; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Verify summary was not generated due to recent update
      verifyNever(() => mockAIService.generateSummary(any()));
    });

    test('should maintain larger context window for AI responses', () async {
      // Add messages to build up context
      for (var i = 0; i < 15; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Get the last call to getResponse
      final lastCall = verify(() => mockAIService.getResponse(
            any(),
            conversationSummary: captureAny(named: 'conversationSummary'),
            recentMessages: captureAny(named: 'recentMessages'),
          )).captured;

      // The captured list alternates between conversationSummary and recentMessages
      // Get the last recentMessages (every second item)
      final recentMessages = lastCall.last as List<ChatMessage>;

      // Verify context window size
      expect(recentMessages.length, lessThanOrEqualTo(10),
          reason: 'Context window should not exceed 10 messages');
      expect(recentMessages.length, greaterThan(0),
          reason: 'Context window should not be empty');
    });
  });

  group('ChatService Error Handling', () {
    test('should handle session loading failure gracefully', () async {
      when(() => mockStorageService.loadCurrentSession())
          .thenThrow(Exception('Mock error'));

      // Create new instance to trigger initialization
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Should not throw error
      expect(chatService.messages, isEmpty);
    });

    test('should handle message saving failure gracefully', () async {
      when(() => mockStorageService.saveChatSession(any()))
          .thenThrow(Exception('Mock error'));

      // Should not throw error
      await chatService.addUserMessage('Test message');
      expect(chatService.messages.length,
          equals(3)); // User message + AI response + error message
    });
  });

  group('ChatService Clear Chat', () {
    test('should clear messages and create new session', () async {
      // Add some messages first
      await chatService.addUserMessage('Test message');
      expect(chatService.messages, isNotEmpty);

      // Clear chat
      await chatService.clearChat();

      // Verify new session was loaded
      verify(() => mockStorageService.loadCurrentSession()).called(2);
    });
  });

  group('ChatService AI Interactions', () {
    test('should generate follow-up questions after user message', () async {
      // Arrange
      const userMessage = 'I had a challenging day at work';
      const aiResponse = 'I understand that must have been difficult';
      final followUpQuestions = [
        'What was the most challenging part?',
        'How did you handle it?',
        'What would you do differently next time?'
      ];

      when(() => mockAIService.getResponse(userMessage))
          .thenAnswer((_) async => aiResponse);
      when(() => mockAIService.generateFollowUpQuestions(any()))
          .thenAnswer((_) async => followUpQuestions);

      // Act
      await chatService.addUserMessage(userMessage);
      final questions = await chatService.generateFollowUpQuestions();

      // Assert
      expect(questions, equals(followUpQuestions));
      verify(() => mockAIService.generateFollowUpQuestions(any())).called(1);
    });

    test('should analyze emotions in user messages', () async {
      // Arrange
      const userMessage = 'I feel really happy today!';
      final expectedEmotions = {
        'joy': 0.9,
        'sadness': 0.0,
        'anger': 0.0,
        'fear': 0.0,
        'surprise': 0.2,
        'love': 0.5,
      };

      when(() => mockAIService.analyzeEmotion(userMessage))
          .thenAnswer((_) async => expectedEmotions);

      // Act
      await chatService.addUserMessage(userMessage);
      final emotions = await chatService.analyzeEmotions(userMessage);

      // Assert
      expect(emotions, equals(expectedEmotions));
      verify(() => mockAIService.analyzeEmotion(userMessage)).called(1);
    });

    test('should generate reflection prompt based on conversation', () async {
      // Arrange
      const userMessage = 'I learned something new today';
      const expectedPrompt =
          'How might this new knowledge change your perspective?';

      when(() => mockAIService.generateReflectionPrompt(any()))
          .thenAnswer((_) async => expectedPrompt);

      // Act
      await chatService.addUserMessage(userMessage);
      final prompt = await chatService.generateReflectionPrompt();

      // Assert
      expect(prompt, equals(expectedPrompt));
      verify(() => mockAIService.generateReflectionPrompt(any())).called(1);
    });

    test('should moderate user content before processing', () async {
      // Arrange
      const safeMessage = 'I had a good day';
      const unsafeMessage = 'UNSAFE CONTENT';

      when(() => mockAIService.moderateContent(safeMessage))
          .thenAnswer((_) async => true);
      when(() => mockAIService.moderateContent(unsafeMessage))
          .thenAnswer((_) async => false);

      // Act & Assert
      await chatService.addUserMessage(safeMessage);
      expect(chatService.messages.last.content, isNot(equals('I apologize')));

      await chatService.addUserMessage(unsafeMessage);
      expect(chatService.messages.last.content, contains('I apologize'));
    });

    test('should handle AI service errors gracefully', () async {
      // Arrange
      const userMessage = 'Test message';
      when(() => mockAIService.getResponse(
            any(),
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).thenThrow(Exception('AI service error'));

      // Act
      await chatService.addUserMessage(userMessage);

      // Assert
      expect(chatService.messages.last.content, contains('I apologize'));
      expect(chatService.messages.last.isUser, isFalse);
    });

    test('should maintain conversation context', () async {
      // Arrange
      const firstMessage = 'I started a new project';
      const secondMessage = 'It\'s going well';
      const contextAwareResponse = 'That\'s great to hear about your project!';
      const summary = 'User started a new project and is making good progress.';

      when(() => mockAIService.getResponse(
            firstMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).thenAnswer((_) async => contextAwareResponse);
      when(() => mockAIService.getResponse(
            secondMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).thenAnswer((_) async => contextAwareResponse);
      when(() => mockAIService.generateSummary(any()))
          .thenAnswer((_) async => summary);

      // Act
      await chatService.addUserMessage(firstMessage);
      await chatService.addUserMessage(secondMessage);

      // Assert
      verify(() => mockAIService.getResponse(
            firstMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).called(1);
      verify(() => mockAIService.getResponse(
            secondMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).called(1);
    });

    test('should use conversation summary in responses', () async {
      // Arrange
      const userMessage = 'How was my progress today?';
      const summary = 'User had a productive day working on their project.';
      const contextAwareResponse =
          'Based on today\'s entries, you made excellent progress on your project.';

      mockSession = mockSession.copyWith(
        historySummary: summary,
        lastSummarized: DateTime.now(),
      );

      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      when(() => mockAIService.getResponse(
            userMessage,
            conversationSummary: summary,
            recentMessages: any(named: 'recentMessages'),
          )).thenAnswer((_) async => contextAwareResponse);

      // Create new instance to use updated mock session
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Act
      await chatService.addUserMessage(userMessage);

      // Assert
      verify(() => mockAIService.getResponse(
            userMessage,
            conversationSummary: summary,
            recentMessages: any(named: 'recentMessages'),
          )).called(1);
      expect(chatService.messages.last.content, equals(contextAwareResponse));
    });

    test('should maintain recent message window', () async {
      // Arrange
      const windowSize = 5;
      final messages = List.generate(
        windowSize + 2,
        (i) => 'Message $i',
      );

      // Act
      for (final message in messages) {
        await chatService.addUserMessage(message);
      }

      // Verify that getResponse was called with the correct window of messages
      verify(() => mockAIService.getResponse(
            messages.last,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).called(1);
    });

    test('should maintain correct message order and timestamps', () async {
      // Arrange
      final startTime = DateTime.now();
      const message1 = 'First message';
      const message2 = 'Second message';

      // Act
      await chatService.addUserMessage(message1);
      await chatService.addUserMessage(message2);

      // Assert
      expect(chatService.messages.length,
          equals(4)); // 2 user messages + 2 AI responses
      expect(chatService.messages[0].content, equals(message1));
      expect(chatService.messages[2].content, equals(message2));
      expect(chatService.messages[0].timestamp.isAfter(startTime), isTrue);
      expect(
          chatService.messages[2].timestamp
              .isAfter(chatService.messages[0].timestamp),
          isTrue);
    });

    test('should persist session across service restarts', () async {
      // Arrange
      const userMessage = 'Test persistence';
      final mockMessages = [
        ChatMessage(
          content: userMessage,
          isUser: true,
          id: 'test-id',
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          content: 'AI Response',
          isUser: false,
          id: 'test-id-2',
          timestamp: DateTime.now(),
        ),
      ];

      mockSession = mockSession.copyWith(messages: mockMessages);
      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      // Act
      await chatService.addUserMessage(userMessage);

      // Simulate service restart
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );
      await Future.delayed(Duration.zero); // Wait for initialization

      // Assert
      verify(() => mockStorageService.loadCurrentSession()).called(2);
      expect(chatService.messages, isNotEmpty);
      expect(chatService.messages.first.content, equals(userMessage));
    });
  });
}
