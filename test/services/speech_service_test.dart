import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/services/speech_service.dart';

class MockSpeechToText extends Mock implements SpeechToText {}

void main() {
  late SpeechService speechService;
  late MockSpeechToText mockSpeechToText;

  setUp(() {
    mockSpeechToText = MockSpeechToText();
    speechService = SpeechService(speechToText: mockSpeechToText);

    // Set up default mock responses
    when(() => mockSpeechToText.initialize(
          onStatus: any(named: 'onStatus'),
          onError: any(named: 'onError'),
        )).thenAnswer((_) async => true);

    when(() => mockSpeechToText.listen(
          onResult: any(named: 'onResult'),
        )).thenAnswer((_) async => true);

    when(() => mockSpeechToText.stop()).thenAnswer((_) async => true);
  });

  group('SpeechService', () {
    test('initial state should be not listening', () {
      expect(speechService.isListening, isFalse);
      expect(speechService.text, isEmpty);
      expect(speechService.confidence, equals(0.0));
    });

    test('initialize should set up speech recognition', () async {
      final result = await speechService.initialize();
      expect(result, isTrue);
      verify(() => mockSpeechToText.initialize(
            onStatus: any(named: 'onStatus'),
            onError: any(named: 'onError'),
          )).called(1);
    });

    test('startListening should start speech recognition if available',
        () async {
      // Arrange
      await speechService.initialize();

      // Act
      await speechService.startListening();

      // Assert
      expect(speechService.isListening, isTrue);
      verify(() => mockSpeechToText.listen(
            onResult: any(named: 'onResult'),
          )).called(1);
    });

    test('stopListening should stop speech recognition if listening', () async {
      // Arrange
      await speechService.initialize();
      await speechService.startListening();

      // Act
      await speechService.stopListening();

      // Assert
      expect(speechService.isListening, isFalse);
      verify(() => mockSpeechToText.stop()).called(1);
    });

    test('clearText should reset text and notify listeners', () {
      // Arrange
      speechService.updateText('test text', 0.8);
      expect(speechService.text, equals('test text'));
      expect(speechService.confidence, equals(0.8));

      // Act
      speechService.clearText();

      // Assert
      expect(speechService.text, isEmpty);
      expect(speechService.confidence, equals(0.0));
    });
  });
}
