import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // Temporary AI responses until we integrate OpenAI
  final List<String> _defaultResponses = [
    "How does that make you feel?",
    "Can you tell me more about that?",
    "That sounds challenging. What helped you cope with it?",
    "I hear you. What would you like to explore about this further?",
    "It's brave of you to share that. How do you feel now compared to when it happened?",
  ];

  // Add a new user message and get AI response
  Future<void> addUserMessage(String content) async {
    final userMessage = ChatMessage.createUserMessage(content);
    _messages.add(userMessage);
    notifyListeners();

    // Get AI response
    await _getAIResponse();
  }

  // Temporary method to get AI response
  Future<void> _getAIResponse() async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Get a random response
    final response =
        _defaultResponses[_messages.length % _defaultResponses.length];

    final aiMessage = ChatMessage.createAIMessage(response);
    _messages.add(aiMessage);
    notifyListeners();
  }

  // Save chat session to Firestore
  Future<void> saveChatSession() async {
    try {
      final chatSession = {
        'timestamp': DateTime.now(),
        'messages': _messages.map((msg) => msg.toJson()).toList(),
      };

      await FirebaseFirestore.instance
          .collection('chat_sessions')
          .add(chatSession);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving chat session: $e');
      }
    }
  }

  // Clear chat
  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
