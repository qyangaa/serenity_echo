import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'interfaces/chat_service_interface.dart';
import 'interfaces/ai_service_interface.dart';
import 'interfaces/storage_service_interface.dart';

class ChatService extends ChangeNotifier implements IChatService {
  IAIService _aiService;
  IStorageService _storageService;
  final List<ChatMessage> _messages = [];

  ChatService({
    required IAIService aiService,
    required IStorageService storageService,
  })  : _aiService = aiService,
        _storageService = storageService;

  void updateDependencies({
    IAIService? aiService,
    IStorageService? storageService,
  }) {
    if (aiService != null) _aiService = aiService;
    if (storageService != null) _storageService = storageService;
  }

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> addUserMessage(String content) async {
    final userMessage = ChatMessage.createUserMessage(content);
    _messages.add(userMessage);
    notifyListeners();

    // Get AI response
    final response = await _aiService.getResponse(content);
    final aiMessage = ChatMessage.createAIMessage(response);
    _messages.add(aiMessage);
    notifyListeners();
  }

  @override
  Future<void> saveChatSession() async {
    try {
      await _storageService.saveChatSession(_messages);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving chat session: $e');
      }
    }
  }

  @override
  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
