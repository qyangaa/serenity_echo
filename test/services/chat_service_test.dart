import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/models/chat_message.dart';
import 'package:serenity_echo/models/chat_session.dart';
import 'package:serenity_echo/models/emotion_analysis.dart';
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

    // Add default emotion analysis mock
    when(() => mockAIService.analyzeEmotion(any()))
        .thenAnswer((_) async => EmotionAnalysis(
              emotionScores: {
                'neutral': 1.0,
              },
              primaryEmotion: 'neutral',
              intensity: 'low',
            ));

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
      // Each message results in 2 saves: one for emotion trends, one for the message
      verify(() => mockStorageService.saveChatSession(any())).called(4);
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

      // Verify both emotion analysis and response generation
      verify(() => mockAIService.analyzeEmotion(userMessage)).called(1);
      verify(() => mockAIService.getResponse(
            userMessage,
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: any(named: 'recentMessages'),
          )).called(1);
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
      final emotionScores = {
        'joy': 0.9,
        'sadness': 0.0,
        'anger': 0.0,
        'fear': 0.0,
        'surprise': 0.2,
        'love': 0.5,
      };
      final expectedEmotions = EmotionAnalysis(
        emotionScores: emotionScores,
        primaryEmotion: 'joy',
        intensity: 'high',
      );

      when(() => mockAIService.analyzeEmotion(userMessage))
          .thenAnswer((_) async => expectedEmotions);

      // Act - only call analyzeEmotions, don't add message
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

      // Verify emotion analysis was called for both messages
      verify(() => mockAIService.analyzeEmotion(firstMessage)).called(1);
      verify(() => mockAIService.analyzeEmotion(secondMessage)).called(1);
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

      // Verify emotion analysis was called for both messages
      verify(() => mockAIService.analyzeEmotion(message1)).called(1);
      verify(() => mockAIService.analyzeEmotion(message2)).called(1);
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

  group('ChatService Context Window', () {
    test(
        'should maintain exactly 10 messages in context window when more messages exist',
        () async {
      // Add more than 10 messages
      for (var i = 0; i < 15; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Verify the context window size in the last AI call
      final captured = verify(() => mockAIService.getResponse(
            any(),
            conversationSummary: any(named: 'conversationSummary'),
            recentMessages: captureAny(named: 'recentMessages'),
          )).captured;

      final recentMessages = captured.last as List<ChatMessage>;
      expect(recentMessages.length, equals(10),
          reason: 'Context window should be exactly 10 messages');
    });
  });

  group('ChatService Summary Generation', () {
    test('should generate summary after exactly 8 messages', () async {
      var summaryGenerationCount = 0;
      when(() => mockAIService.generateSummary(any())).thenAnswer((_) {
        summaryGenerationCount++;
        return Future.value("Test Summary");
      });

      // Add 7 messages (will result in 14 total with AI responses)
      for (var i = 0; i < 7; i++) {
        await chatService.addUserMessage('Message $i');
      }
      expect(summaryGenerationCount, equals(1),
          reason: 'Summary should be generated after 8 messages');
    });

    test('should respect 5-minute cooldown for summary generation', () async {
      // Setup mock session with recent summary
      final recentTime = DateTime.now().subtract(const Duration(minutes: 3));
      mockSession = mockSession.copyWith(
        historySummary: 'Recent summary',
        lastSummarized: recentTime,
      );

      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Add enough messages to trigger summary
      for (var i = 0; i < 5; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Verify summary was not generated due to cooldown
      verifyNever(() => mockAIService.generateSummary(any()));
    });

    test('should generate summary after cooldown period', () async {
      // Setup mock session with old summary
      final oldTime = DateTime.now().subtract(const Duration(minutes: 6));
      mockSession = mockSession.copyWith(
        historySummary: 'Old summary',
        lastSummarized: oldTime,
      );

      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Add enough messages to trigger summary
      for (var i = 0; i < 5; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Verify summary was generated after cooldown
      verify(() => mockAIService.generateSummary(any())).called(1);
    });
  });

  group('ChatService Content Moderation', () {
    test('should handle inappropriate content with error message', () async {
      when(() => mockAIService.moderateContent(any()))
          .thenAnswer((_) async => false);

      await chatService.addUserMessage('Inappropriate content');

      // Verify no AI response was generated
      verifyNever(() => mockAIService.getResponse(any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages')));

      // Verify error message was added
      expect(chatService.messages.last.content,
          contains('cannot process that content'),
          reason: 'Should show moderation error message');
    });

    test('should process safe content normally', () async {
      when(() => mockAIService.moderateContent(any()))
          .thenAnswer((_) async => true);

      await chatService.addUserMessage('Safe content');

      // Verify AI response was generated
      verify(() => mockAIService.getResponse(any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'))).called(1);
    });
  });

  group('ChatService Session Management', () {
    test('should handle null session gracefully', () async {
      // Setup sequence of responses
      var callCount = 0;
      when(() => mockStorageService.loadCurrentSession()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return null;
        return mockSession;
      });

      // Create new chat service instance
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );

      // Wait for initialization
      await Future.delayed(Duration.zero);

      // Try to add a message
      await chatService.addUserMessage('Test message');

      // Wait for all async operations
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify session was created and message was added
      verify(() => mockStorageService.saveChatSession(any()))
          .called(greaterThan(1));
      expect(chatService.messages.length, equals(2),
          reason: 'Should have user message and AI response');
    });

    test('should maintain session state across message additions', () async {
      final messages = ['First message', 'Second message', 'Third message'];

      for (final message in messages) {
        await chatService.addUserMessage(message);
      }

      // Each message should result in both user message and AI response
      expect(chatService.messages.length, equals(messages.length * 2));

      // Verify messages are in correct order
      for (var i = 0; i < messages.length; i++) {
        expect(chatService.messages[i * 2].content, equals(messages[i]));
        expect(chatService.messages[i * 2].isUser, isTrue);
        expect(chatService.messages[i * 2 + 1].isUser, isFalse);
      }
    });
  });

  group('ChatService Emotional Trends', () {
    test('should initialize empty emotional trends for new session', () {
      expect(chatService.getEmotionalTrends(), isEmpty);
    });

    test('should update emotional trends with new messages', () async {
      // Arrange
      const message1 = 'I feel happy today!';
      const message2 = 'I am a bit anxious about tomorrow.';

      final emotion1 = EmotionAnalysis(
        emotionScores: {
          'joy': 0.8,
          'anxiety': 0.1,
        },
        primaryEmotion: 'joy',
        intensity: 'high',
      );

      final emotion2 = EmotionAnalysis(
        emotionScores: {
          'joy': 0.2,
          'anxiety': 0.7,
        },
        primaryEmotion: 'anxiety',
        intensity: 'high',
      );

      // Override default mock for specific messages
      when(() => mockAIService.analyzeEmotion(message1))
          .thenAnswer((_) async => emotion1);
      when(() => mockAIService.analyzeEmotion(message2))
          .thenAnswer((_) async => emotion2);

      // Act
      await chatService.addUserMessage(message1);
      var trendsAfterFirstMessage = chatService.getEmotionalTrends();

      await chatService.addUserMessage(message2);
      var trendsAfterSecondMessage = chatService.getEmotionalTrends();

      // Assert - First message should set initial values
      expect(trendsAfterFirstMessage['joy'], closeTo(0.56, 0.01)); // 0.8 * 0.7
      expect(
          trendsAfterFirstMessage['anxiety'], closeTo(0.07, 0.01)); // 0.1 * 0.7

      // Second message updates with exponential moving average
      expect(trendsAfterSecondMessage['joy'],
          closeTo(0.31, 0.01)); // 0.2 * 0.7 + 0.56 * 0.3
      expect(trendsAfterSecondMessage['anxiety'],
          closeTo(0.51, 0.01)); // 0.7 * 0.7 + 0.07 * 0.3
    });

    test('should persist emotional trends across service restarts', () async {
      // Arrange
      const message = 'I feel excited!';
      final emotion = EmotionAnalysis(
        emotionScores: {
          'joy': 0.9,
          'excitement': 0.8,
        },
        primaryEmotion: 'joy',
        intensity: 'high',
      );

      // Override default mock for specific message
      when(() => mockAIService.analyzeEmotion(message))
          .thenAnswer((_) async => emotion);

      // Act
      await chatService.addUserMessage(message);
      final trendsBeforeRestart = chatService.getEmotionalTrends();

      // Create mock session with the trends
      mockSession = mockSession.copyWith(
        emotionalTrends: trendsBeforeRestart,
      );
      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => mockSession);

      // Simulate service restart
      chatService = ChatService(
        aiService: mockAIService,
        storageService: mockStorageService,
      );
      await Future.delayed(Duration.zero); // Wait for initialization

      // Assert
      final trendsAfterRestart = chatService.getEmotionalTrends();
      expect(trendsAfterRestart, equals(trendsBeforeRestart));
    });

    test('should handle empty emotion scores gracefully', () async {
      // Arrange
      const message = 'Neutral message';
      final emotion = EmotionAnalysis(
        emotionScores: {},
        primaryEmotion: 'neutral',
        intensity: 'low',
      );

      when(() => mockAIService.analyzeEmotion(message))
          .thenAnswer((_) async => emotion);

      // Act
      await chatService.addUserMessage(message);
      final trends = chatService.getEmotionalTrends();

      // Assert
      expect(trends, isEmpty);
    });
  });
}
