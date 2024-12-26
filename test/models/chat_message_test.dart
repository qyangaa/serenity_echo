import 'package:flutter_test/flutter_test.dart';
import 'package:serenity_echo/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('createUserMessage should create message with correct properties', () {
      final message = ChatMessage.createUserMessage('Hello');

      expect(message.content, equals('Hello'));
      expect(message.isUser, isTrue);
      expect(message.id, isNotEmpty);
      expect(message.timestamp, isNotNull);
    });

    test('createAIMessage should create message with correct properties', () {
      final message = ChatMessage.createAIMessage('Hi there');

      expect(message.content, equals('Hi there'));
      expect(message.isUser, isFalse);
      expect(message.id, isNotEmpty);
      expect(message.timestamp, isNotNull);
    });

    test('toChatUIMessage should convert to correct UI format', () {
      final message = ChatMessage.createUserMessage('Test message');
      final uiMessage = message.toChatUIMessage();

      expect(uiMessage.id, equals(message.id));
      expect(uiMessage.text, equals(message.content));
      expect(uiMessage.author.id, equals('user'));
      expect(uiMessage.createdAt,
          equals(message.timestamp.millisecondsSinceEpoch));
    });

    test('toJson and fromJson should maintain data integrity', () {
      final original = ChatMessage.createUserMessage('Test message');
      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.content, equals(original.content));
      expect(restored.isUser, equals(original.isUser));
      expect(restored.timestamp.toIso8601String(),
          equals(original.timestamp.toIso8601String()));
    });
  });
}
