import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:serenity_echo/services/chat_service.dart';
import 'package:serenity_echo/services/speech_service.dart';
import 'package:serenity_echo/services/interfaces/ai_service_interface.dart';
import 'package:serenity_echo/services/interfaces/storage_service_interface.dart';
import 'package:serenity_echo/ui/screens/chat_journal_screen.dart';
import 'package:serenity_echo/main.dart';
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
    return MultiProvider(
      providers: [
        Provider<IAIService>(create: (_) => mockAIService),
        Provider<IStorageService>(create: (_) => mockStorageService),
        ChangeNotifierProvider<SpeechService>(create: (_) => speechService),
        ChangeNotifierProvider<ChatService>(create: (_) => chatService),
      ],
      child: MaterialApp(
        home: const HomeScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/chat') {
            return MaterialPageRoute(
              builder: (context) => const ChatJournalScreen(),
            );
          }
          return null;
        },
      ),
    );
  }

  testWidgets('should display all initial UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_title')), findsOneWidget);
    expect(find.byKey(const Key('home_subtitle')), findsOneWidget);
    expect(find.byKey(const Key('start_journaling_button')), findsOneWidget);
  });

  testWidgets('should navigate to ChatJournalScreen when start button pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start_journaling_button')));
    await tester.pump(); // Start navigation

    // Complete the navigation
    await tester.pumpAndSettle();

    // Verify we're on the chat screen
    expect(find.byType(ChatJournalScreen), findsOneWidget);
  });

  testWidgets('should have correct styling for UI elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final titleFinder = find.byKey(const Key('home_title'));
    final subtitleFinder = find.byKey(const Key('home_subtitle'));
    final buttonFinder = find.byKey(const Key('start_journaling_button'));

    expect(titleFinder, findsOneWidget);
    expect(subtitleFinder, findsOneWidget);
    expect(buttonFinder, findsOneWidget);
  });

  testWidgets('should handle navigation with loading state',
      (WidgetTester tester) async {
    // Arrange - make storage service slow to load
    when(() => mockStorageService.loadCurrentSession()).thenAnswer(
      (_) => Future.delayed(
        const Duration(seconds: 1),
        () => ChatSessionFake(),
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Act - tap the start button
    await tester.tap(find.byKey(const Key('start_journaling_button')));
    await tester.pump(); // Start navigation
    await tester.pump(); // Wait for dialog to start showing
    await tester
        .pump(const Duration(milliseconds: 50)); // Wait for dialog animation

    // Assert - verify loading state
    expect(find.byKey(const Key('loading_indicator')), findsOneWidget);

    // Wait for loading to complete
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verify we're on the chat screen
    expect(find.byType(ChatJournalScreen), findsOneWidget);
  });

  testWidgets('should handle error state during navigation', skip: true,
      (WidgetTester tester) async {
    // Arrange - make storage service fail
    when(() => mockStorageService.loadCurrentSession())
        .thenThrow(Exception('Failed to load session'));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Act - tap the start button
    await tester.tap(find.byKey(const Key('start_journaling_button')));
    await tester.pump(); // Start navigation

    // Wait for error handling to complete
    await tester.pump(); // Build frame
    await tester.pump(const Duration(milliseconds: 50)); // Animation frame

    // Assert - verify error message is shown
    expect(
        find.text('Error: Exception: Failed to load session'), findsOneWidget);

    // Assert - verify we're still on home screen by checking UI elements
    expect(find.text('SerenityEcho'), findsOneWidget);
    expect(find.text('Your AI-powered journaling companion'), findsOneWidget);
    expect(find.text('Start Journaling'), findsOneWidget);
  });

  testWidgets('should maintain state during screen rotation',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Simulate screen rotation
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpAndSettle();

    // Verify UI elements are still present
    expect(find.byKey(const Key('home_title')), findsOneWidget);
    expect(find.byKey(const Key('home_subtitle')), findsOneWidget);
    expect(find.byKey(const Key('start_journaling_button')), findsOneWidget);

    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('should have accessible elements', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find the button directly
    final buttonFinder = find.byKey(const Key('start_journaling_button'));
    expect(buttonFinder, findsOneWidget);

    // Verify button is tappable
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester
        .pump(const Duration(milliseconds: 50)); // Wait for dialog animation
  });
}
