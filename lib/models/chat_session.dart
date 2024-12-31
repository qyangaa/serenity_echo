import 'package:uuid/uuid.dart';
import 'chat_message.dart';

class ChatSession {
  final String id;
  final List<ChatMessage> messages;
  final int messageCount;
  final DateTime? lastSummarized;
  final String summary;
  final DateTime created;
  final DateTime updated;

  const ChatSession({
    required this.id,
    required this.messages,
    required this.messageCount,
    this.lastSummarized,
    this.summary = '',
    required this.created,
    required this.updated,
  });

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'messageCount': messageCount,
      'lastSummarized': lastSummarized?.toIso8601String(),
      'summary': summary,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  factory ChatSession.fromJson(String id, Map<String, dynamic> json) {
    return ChatSession(
      id: id,
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      messageCount: json['messageCount'] as int? ?? 0,
      lastSummarized: json['lastSummarized'] != null
          ? DateTime.parse(json['lastSummarized'] as String)
          : null,
      summary: json['summary'] as String? ?? '',
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  factory ChatSession.create() {
    final now = DateTime.now();
    return ChatSession(
      id: const Uuid().v4(),
      messages: const [],
      messageCount: 0,
      lastSummarized: null,
      summary: '',
      created: now,
      updated: now,
    );
  }

  ChatSession copyWith({
    String? id,
    List<ChatMessage>? messages,
    int? messageCount,
    DateTime? lastSummarized,
    String? summary,
    DateTime? created,
    DateTime? updated,
  }) {
    return ChatSession(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      messageCount: messageCount ?? this.messageCount,
      lastSummarized: lastSummarized ?? this.lastSummarized,
      summary: summary ?? this.summary,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }
}
