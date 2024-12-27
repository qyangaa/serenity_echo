import 'package:mocktail/mocktail.dart';
import 'package:serenity_echo/models/chat_session.dart';
import 'package:serenity_echo/models/chat_message.dart';

class ChatSessionFake extends Fake implements ChatSession {
  @override
  String get id => 'fake_session_id';

  @override
  List<ChatMessage> get messages => [];

  @override
  int get messageCount => 0;

  @override
  DateTime get created => DateTime.now();

  @override
  DateTime get updated => DateTime.now();

  @override
  String? get historySummary => null;

  @override
  DateTime? get lastSummarized => null;

  @override
  ChatSession copyWith({
    String? id,
    List<ChatMessage>? messages,
    int? messageCount,
    DateTime? created,
    DateTime? updated,
    String? historySummary,
    DateTime? lastSummarized,
    Map<String, double>? emotionalTrends,
  }) {
    return ChatSession(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      messageCount: messageCount ?? this.messageCount,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      historySummary: historySummary ?? this.historySummary,
      lastSummarized: lastSummarized ?? this.lastSummarized,
      emotionalTrends: emotionalTrends ?? {},
    );
  }
}
