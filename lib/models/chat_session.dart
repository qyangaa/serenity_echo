import 'chat_message.dart';

class ChatSession {
  final String id;
  final List<ChatMessage> messages;
  final String? historySummary;
  final DateTime? lastSummarized;
  final int messageCount;
  final DateTime created;
  final DateTime updated;
  final Map<String, double>? emotionalTrends;

  ChatSession({
    required this.id,
    required this.messages,
    this.historySummary,
    this.lastSummarized,
    required this.messageCount,
    required this.created,
    required this.updated,
    this.emotionalTrends,
  });

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'historySummary': historySummary,
      'lastSummarized': lastSummarized?.toIso8601String(),
      'messageCount': messageCount,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
      'emotionalTrends': emotionalTrends,
    };
  }

  factory ChatSession.fromJson(String id, Map<String, dynamic> json) {
    return ChatSession(
      id: id,
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      historySummary: json['historySummary'] as String?,
      lastSummarized: json['lastSummarized'] != null
          ? DateTime.parse(json['lastSummarized'] as String)
          : null,
      messageCount: json['messageCount'] as int? ?? 0,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
      emotionalTrends: (json['emotionalTrends'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as double),
      ),
    );
  }

  factory ChatSession.create() {
    return ChatSession(
      id: '', // Will be set by Firestore
      messages: [],
      messageCount: 0,
      created: DateTime.now(),
      updated: DateTime.now(),
    );
  }

  ChatSession copyWith({
    String? id,
    List<ChatMessage>? messages,
    String? historySummary,
    DateTime? lastSummarized,
    int? messageCount,
    DateTime? created,
    DateTime? updated,
    Map<String, double>? emotionalTrends,
  }) {
    return ChatSession(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      historySummary: historySummary ?? this.historySummary,
      lastSummarized: lastSummarized ?? this.lastSummarized,
      messageCount: messageCount ?? this.messageCount,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      emotionalTrends: emotionalTrends ?? this.emotionalTrends,
    );
  }
}
