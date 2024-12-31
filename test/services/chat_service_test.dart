import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
  late ChatSession testSession;

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
    when(() => mockAIService.getResponse(any()))
        .thenAnswer((_) async => "Mock AI Response");
    when(() => mockAIService.generateSummary(any()))
        .thenAnswer((_) async => "Mock Summary");
    when(() => mockAIService.moderateContent(any()))
        .thenAnswer((_) async => true);
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

    testSession = ChatSession.create();
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
      // Setup
      when(() => mockStorageService.loadCurrentSession())
          .thenAnswer((_) async => testSession);
      when(() => mockStorageService.saveChatSession(any()))
          .thenAnswer((_) async => {});
      when(() => mockStorageService.updateSessionSummary(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockAIService.getResponse(any()))
          .thenAnswer((_) async => 'Test response');
      when(() => mockAIService.generateSummary(any()))
          .thenAnswer((_) async => 'Mock Summary');

      // Execute
      await chatService.addUserMessage('First message');
      await chatService.addUserMessage('Second message');

      // Verify
      verify(() => mockStorageService.loadCurrentSession()).called(1);
      // 4 calls: 2 for user messages, 2 for summaries
      verify(() => mockStorageService.saveChatSession(any())).called(4);
    });
  });

  group('ChatService Message Handling', () {
    test('should add user message and get AI response', () async {
      const userMessage = 'Hello';
      const aiResponse = 'Hi there!';

      when(() => mockAIService.getResponse(userMessage))
          .thenAnswer((_) async => aiResponse);

      await chatService.addUserMessage(userMessage);

      expect(chatService.messages.length, equals(2));
      expect(chatService.messages[0].content, equals(userMessage));
      expect(chatService.messages[0].isUser, isTrue);
      expect(chatService.messages[1].content, equals(aiResponse));
      expect(chatService.messages[1].isUser, isFalse);
    });

    test('should generate summary after reaching message threshold', () async {
      // Add enough messages to trigger summary
      for (var i = 0; i < 10; i++) {
        await chatService.addUserMessage('Message $i');
      }

      // Verify summary was generated and saved
      verify(() => mockAIService.generateSummary(any())).called(greaterThan(0));
      verify(() => mockStorageService.updateSessionSummary(any(), any()))
          .called(greaterThan(0));
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
      when(() => mockAIService.getResponse(any()))
          .thenThrow(Exception('AI service error'));

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

      when(() => mockAIService.getResponse(firstMessage))
          .thenAnswer((_) async => contextAwareResponse);
      when(() => mockAIService.getResponse(secondMessage))
          .thenAnswer((_) async => contextAwareResponse);

      // Act
      await chatService.addUserMessage(firstMessage);
      await chatService.addUserMessage(secondMessage);

      // Assert
      verify(() => mockAIService.getResponse(firstMessage)).called(1);
      verify(() => mockAIService.getResponse(secondMessage)).called(1);
    });
  });
}
