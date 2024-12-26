import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
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

  setUpAll(() {
    registerFallbackValue(ChatSessionFake());
  });

  setUp(() {
    mockAIService = MockAIService();
    mockStorageService = MockStorageService();
    speechService = SpeechService();

    // Set up mock responses
    when(() => mockAIService.getResponse(any()))
        .thenAnswer((_) async => "Mock AI Response");
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

  testWidgets('should display initial UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Journal Chat'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('should clear chat when delete button is pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.loadCurrentSession())
        .called(greaterThan(0));
  });

  testWidgets('should show microphone button in correct states',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNothing);
  });
}
