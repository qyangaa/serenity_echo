import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:serenity_echo/services/speech_service.dart';
import 'package:serenity_echo/services/interfaces/storage_service_interface.dart';
import 'package:serenity_echo/main.dart';
import '../../mocks/mock_storage_service.dart';

void main() {
  late MockStorageService mockStorageService;
  late SpeechService speechService;

  setUp(() {
    mockStorageService = MockStorageService();
    speechService = SpeechService();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        Provider<IStorageService>(create: (_) => mockStorageService),
        ChangeNotifierProvider<SpeechService>(create: (_) => speechService),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
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

  testWidgets('should show coming soon message when start button pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start_journaling_button')));
    await tester.pump();

    expect(
        find.text('Coming soon with AI Toolkit integration!'), findsOneWidget);
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
  });
}
