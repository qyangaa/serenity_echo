import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/models/chat_message.dart';
import 'package:serenity_echo/services/chat_service.dart';
import '../mocks/mock_ai_service.dart';
import '../mocks/mock_storage_service.dart';

void main() {
  late ChatService chatService;
  late MockAIService mockAIService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockAIService = MockAIService();
    mockStorageService = MockStorageService();
    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );

    // Set up default mock responses
    when(() => mockAIService.getResponse(any()))
        .thenAnswer((_) async => "Mock AI Response");
    when(() => mockStorageService.saveChatSession(any()))
        .thenAnswer((_) async => {});
  });

  group('ChatService', () {
    test('initial messages list should be empty', () {
      expect(chatService.messages, isEmpty);
    });

    test('addUserMessage should add message and get AI response', () async {
      // Arrange
      const userMessage = 'Hello';
      const aiResponse = 'Hi there!';
      when(() => mockAIService.getResponse(userMessage))
          .thenAnswer((_) async => aiResponse);

      // Act
      await chatService.addUserMessage(userMessage);

      // Assert
      expect(chatService.messages.length, equals(2));
      expect(chatService.messages[0].content, equals(userMessage));
      expect(chatService.messages[0].isUser, isTrue);
      expect(chatService.messages[1].content, equals(aiResponse));
      expect(chatService.messages[1].isUser, isFalse);
      verify(() => mockAIService.getResponse(userMessage)).called(1);
    });

    test('clearChat should empty the messages list', () async {
      // Arrange
      await chatService.addUserMessage('Test message');
      expect(chatService.messages, isNotEmpty);

      // Act
      chatService.clearChat();

      // Assert
      expect(chatService.messages, isEmpty);
    });

    test('saveChatSession should call storage service', () async {
      // Arrange
      await chatService.addUserMessage('Test message');

      // Act
      await chatService.saveChatSession();

      // Assert
      verify(() => mockStorageService.saveChatSession(any())).called(1);
    });
  });
}
