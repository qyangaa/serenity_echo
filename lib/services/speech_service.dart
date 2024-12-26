import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService extends ChangeNotifier {
  final SpeechToText _speechToText;
  bool _isListening = false;
  String _text = '';
  double _confidence = 0.0;

  SpeechService({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  bool get isListening => _isListening;
  String get text => _text;
  double get confidence => _confidence;

  Future<bool> initialize() async {
    final bool available = await _speechToText.initialize(
      onStatus: (status) => print('Speech recognition status: $status'),
      onError: (errorNotification) =>
          print('Speech recognition error: $errorNotification'),
    );
    return available;
  }

  Future<void> startListening() async {
    if (!_isListening) {
      final bool available = await _speechToText.initialize();
      if (available) {
        _isListening = true;
        notifyListeners();

        await _speechToText.listen(
          onResult: (result) {
            _text = result.recognizedWords;
            _confidence = result.confidence;
            notifyListeners();
          },
        );
      }
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  void clearText() {
    _text = '';
    _confidence = 0.0;
    notifyListeners();
  }

  // For testing purposes
  @visibleForTesting
  void updateText(String text, double confidence) {
    _text = text;
    _confidence = confidence;
    notifyListeners();
  }
}
