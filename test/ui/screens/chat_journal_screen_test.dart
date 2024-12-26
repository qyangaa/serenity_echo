import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:serenity_echo/services/chat_service.dart';
import 'package:serenity_echo/services/speech_service.dart';
import 'package:serenity_echo/ui/screens/chat_journal_screen.dart';
import '../../mocks/mock_ai_service.dart';
import '../../mocks/mock_storage_service.dart';

void main() {
  late ChatService chatService;
  late SpeechService speechService;
  late MockAIService mockAIService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockAIService = MockAIService();
    mockStorageService = MockStorageService();

    // Set up default mock responses
    when(() => mockAIService.getResponse(any()))
        .thenAnswer((_) async => "Mock AI Response");
    when(() => mockStorageService.saveChatSession(any()))
        .thenAnswer((_) async => {});

    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );
    speechService = SpeechService();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(
            value: chatService,
          ),
          ChangeNotifierProvider<SpeechService>.value(
            value: speechService,
          ),
        ],
        child: const ChatJournalScreen(),
      ),
    );
  }

  group('ChatJournalScreen', () {
    testWidgets('should display initial UI elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Journal Chat'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should show snackbar when saving journal', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('Journal saved!'), findsOneWidget);
      verify(() => mockStorageService.saveChatSession(any())).called(1);
    });

    testWidgets('should clear chat when delete button is pressed',
        (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await chatService.addUserMessage('Test message');
      await tester.pump();
      expect(find.text('Test message'), findsOneWidget);

      // Act
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      // Assert
      expect(find.text('Test message'), findsNothing);
      expect(chatService.messages, isEmpty);
    });

    testWidgets('should show microphone button in correct states',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Initial state
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);

      // When listening
      speechService.updateText('Testing', 0.8);
      await tester.pump();

      expect(find.text('Testing'), findsOneWidget);
    });
  });
}
