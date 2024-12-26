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
}
