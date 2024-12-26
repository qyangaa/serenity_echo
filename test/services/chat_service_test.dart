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
      expect(chatService.messages.length, equals(2));
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
}
