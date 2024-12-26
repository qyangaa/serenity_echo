import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  // Convert to chat UI message
  types.TextMessage toChatUIMessage() {
    return types.TextMessage(
      id: id,
      text: content,
      author: types.User(
        id: isUser ? 'user' : 'ai',
        firstName: isUser ? 'You' : 'SerenityEcho',
      ),
      createdAt: timestamp.millisecondsSinceEpoch,
    );
  }

  // Create a new user message
  static ChatMessage createUserMessage(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  // Create a new AI message
  static ChatMessage createAIMessage(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
