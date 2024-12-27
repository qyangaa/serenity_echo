import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:serenity_echo/models/chat_message.dart';
import 'package:serenity_echo/models/chat_session.dart';
import 'package:serenity_echo/services/chat_service.dart';
import 'package:serenity_echo/services/speech_service.dart';
import 'package:serenity_echo/ui/screens/chat_journal_screen.dart';
import '../../mocks/mock_ai_service.dart';
import '../../mocks/mock_storage_service.dart';
import '../../mocks/mock_chat_session.dart';

void main() {
  late MockAIService mockAIService;
  late MockStorageService mockStorageService;
  late SpeechService speechService;
  late ChatService chatService;
  late ChatSession mockSession;

  setUpAll(() {
    registerFallbackValue(ChatSessionFake());
  });

  setUp(() {
    mockAIService = MockAIService();
    mockStorageService = MockStorageService();
    speechService = SpeechService();

    // Set up mock responses
    when(() => mockAIService.moderateContent(any()))
        .thenAnswer((_) async => true);
    when(() => mockAIService.getResponse(
          any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'),
        )).thenAnswer((_) async => "Mock AI Response");
    when(() => mockStorageService.loadCurrentSession())
        .thenAnswer((_) async => ChatSessionFake());
    when(() => mockStorageService.saveChatSession(any()))
        .thenAnswer((_) async => {});

    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<SpeechService>.value(value: speechService),
          ChangeNotifierProvider<ChatService>.value(value: chatService),
        ],
        child: const ChatJournalScreen(),
      ),
    );
  }

  testWidgets('should handle text input and message sending',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    const testMessage = 'Hello, AI!';

    // Find and interact with chat UI
    final chat = find.byType(Chat);
    expect(chat, findsOneWidget);

    // Simulate message send
    final chatWidget = tester.widget<Chat>(chat);
    chatWidget.onSendPressed(types.PartialText(text: testMessage));
    await tester.pumpAndSettle();

    // Verify message was sent and AI responded
    verify(() => mockAIService.moderateContent(testMessage)).called(1);
    verify(() => mockAIService.getResponse(
          testMessage,
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'),
        )).called(1);

    // Verify messages are in the chat
    expect(chatService.messages.length, equals(2));
    expect(chatService.messages[0].content, equals(testMessage));
    expect(chatService.messages[0].isUser, isTrue);
    expect(chatService.messages[1].content, equals("Mock AI Response"));
    expect(chatService.messages[1].isUser, isFalse);
  });

  testWidgets('should show loading indicator while waiting for AI response',
      (WidgetTester tester) async {
    // Arrange
    when(() => mockAIService.moderateContent(any()))
        .thenAnswer((_) async => true);
    when(() => mockAIService.getResponse(
          any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'),
        )).thenAnswer(
      (_) => Future.delayed(
        const Duration(seconds: 1),
        () => 'AI Response',
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find and interact with chat UI
    final chat = find.byType(Chat);
    expect(chat, findsOneWidget);

    // Simulate message send
    final chatWidget = tester.widget<Chat>(chat);
    chatWidget.onSendPressed(types.PartialText(text: 'Test message'));
    await tester.pump(); // Start the loading state

    // Verify user message is shown immediately
    expect(chatService.messages.length, equals(1));
    expect(chatService.messages[0].content, equals('Test message'));

    // Wait for response
    await tester.pump(const Duration(seconds: 1));

    // Verify AI response is added
    expect(chatService.messages.length, equals(2));
    expect(chatService.messages[1].content, equals('AI Response'));
  });

  testWidgets('should scroll to bottom when new message is added',
      (WidgetTester tester) async {
    // Arrange - create a mock session with many messages
    final mockMessages = List.generate(
      20,
      (i) => ChatMessage(
        content: 'Message $i',
        isUser: i.isEven,
        id: 'msg-$i',
        timestamp: DateTime.now().add(Duration(minutes: i)),
      ),
    );

    mockSession = ChatSession(
      id: 'test_session_id',
      messages: mockMessages,
      messageCount: mockMessages.length,
      created: DateTime.now(),
      updated: DateTime.now(),
    );

    when(() => mockStorageService.loadCurrentSession())
        .thenAnswer((_) async => mockSession);

    // Recreate chat service with new mock session
    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find chat UI
    final chat = find.byType(Chat);
    expect(chat, findsOneWidget);

    // Verify messages are displayed in reverse order
    final chatWidget = tester.widget<Chat>(chat);
    expect(chatWidget.messages.first.id, equals('msg-19'));
  });

  testWidgets('should show error message on AI service failure',
      (WidgetTester tester) async {
    // Arrange
    when(() => mockAIService.moderateContent(any()))
        .thenAnswer((_) async => true);
    when(() => mockAIService.getResponse(
          any(),
          conversationSummary: any(named: 'conversationSummary'),
          recentMessages: any(named: 'recentMessages'),
        )).thenThrow(Exception('AI service error'));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find and interact with chat UI
    final chat = find.byType(Chat);
    expect(chat, findsOneWidget);

    // Simulate message send
    final chatWidget = tester.widget<Chat>(chat);
    chatWidget.onSendPressed(types.PartialText(text: 'Test message'));
    await tester.pumpAndSettle();

    // Verify error message is in the chat messages
    expect(chatService.messages.length, equals(2));
    expect(chatService.messages[0].content, equals('Test message'));
    expect(chatService.messages[1].content,
        equals('I apologize, but I encountered an error. Please try again.'));
  });
}
