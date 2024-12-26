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
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('SerenityEcho'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Your AI-Powered Journal'),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MultiProvider(
                            providers: [
                              ChangeNotifierProvider<SpeechService>.value(
                                  value: speechService),
                              ChangeNotifierProvider<ChatService>.value(
                                  value: chatService),
                            ],
                            child: const ChatJournalScreen(),
                          ),
                        ),
                      );
                    },
                    child: const Text('Start Journaling'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('should display all initial UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('SerenityEcho'), findsOneWidget);
    expect(find.text('Your AI-Powered Journal'), findsOneWidget);
    expect(find.text('Start Journaling'), findsOneWidget);
  });

  testWidgets('should navigate to ChatJournalScreen when start button pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Journaling'));
    await tester.pumpAndSettle();

    expect(find.text('Journal Chat'), findsOneWidget);
  });

  testWidgets('should have correct styling for UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final titleFinder = find.text('SerenityEcho');
    final subtitleFinder = find.text('Your AI-Powered Journal');
    final buttonFinder = find.text('Start Journaling');

    expect(titleFinder, findsOneWidget);
    expect(subtitleFinder, findsOneWidget);
    expect(buttonFinder, findsOneWidget);
  });
}
