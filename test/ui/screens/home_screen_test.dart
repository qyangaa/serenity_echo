import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:serenity_echo/main.dart';
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
    chatService = ChatService(
      aiService: mockAIService,
      storageService: mockStorageService,
    );
    speechService = SpeechService();
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }

  Widget createWidgetWithProviders({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatService>.value(
          value: chatService,
        ),
        ChangeNotifierProvider<SpeechService>.value(
          value: speechService,
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('HomeScreen', () {
    testWidgets('should display all initial UI elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('SerenityEcho'), findsOneWidget);
      expect(find.text('Welcome to SerenityEcho'), findsOneWidget);
      expect(find.text('Your AI-powered journaling companion'), findsOneWidget);
      expect(find.text('Start Journaling'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets(
        'should navigate to ChatJournalScreen when start button pressed',
        (tester) async {
      await tester.pumpWidget(createWidgetWithProviders(
        child: const HomeScreen(),
      ));

      await tester.tap(find.text('Start Journaling'));
      await tester.pumpAndSettle();

      // Verify navigation occurred
      expect(find.byType(ChatJournalScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('should have correct styling for UI elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Check icon size
      final icon = tester.widget<Icon>(
        find.byType(Icon).first,
      );
      expect(icon.size, equals(64));
      expect(icon.color, equals(Colors.teal));

      // Check text styling
      final titleText = tester.widget<Text>(
        find.text('Welcome to SerenityEcho'),
      );
      expect(titleText.style?.fontSize, equals(24));
      expect(titleText.style?.fontWeight, equals(FontWeight.bold));

      final subtitleText = tester.widget<Text>(
        find.text('Your AI-powered journaling companion'),
      );
      expect(subtitleText.style?.fontSize, equals(16));
      expect(subtitleText.style?.color, equals(Colors.grey));
    });
  });
}
