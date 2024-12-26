import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'interfaces/chat_service_interface.dart';
import 'interfaces/ai_service_interface.dart';
import 'interfaces/storage_service_interface.dart';

class ChatService extends ChangeNotifier implements IChatService {
  IAIService _aiService;
  IStorageService _storageService;
  ChatSession? _currentSession;
  static const int _summarizeAfterMessages = 10;
  bool _isLoading = false;

  ChatService({
    required IAIService aiService,
    required IStorageService storageService,
  })  : _aiService = aiService,
        _storageService = storageService {
    _loadCurrentSession();
  }

  void updateDependencies({
    IAIService? aiService,
    IStorageService? storageService,
  }) {
    if (aiService != null) _aiService = aiService;
    if (storageService != null) _storageService = storageService;
  }

  Future<void> _loadCurrentSession() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      _currentSession = await _storageService.loadCurrentSession();
      if (_currentSession == null) {
        if (kDebugMode) {
          print('No current session found, creating new one');
        }
        // Create a new session
        _currentSession = ChatSession.create();
        // Save it to get an ID
        await _storageService.saveChatSession(_currentSession!);
        // Reload to ensure we have the latest state
        _currentSession = await _storageService.loadCurrentSession();
        if (kDebugMode) {
          print('Created new session with ID: ${_currentSession?.id}');
        }
      } else {
        if (kDebugMode) {
          print('Loaded existing session: ${_currentSession?.id}');
        }
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current session: $e');
      }
    } finally {
      _isLoading = false;
    }
  }

  @override
  List<ChatMessage> get messages => _currentSession?.messages ?? [];

  @override
  Future<void> addUserMessage(String content) async {
    try {
      if (_currentSession == null) {
        await _loadCurrentSession();
      }

      // Double-check we have a session after loading
      if (_currentSession == null) {
        if (kDebugMode) {
          print('Creating emergency session as load failed');
        }
        _currentSession = ChatSession.create();
        await _storageService.saveChatSession(_currentSession!);
      }

      // Add user message
      final userMessage = ChatMessage.createUserMessage(content);
      final updatedMessages = [..._currentSession!.messages, userMessage];

      // Update session with user message
      _currentSession = _currentSession!.copyWith(
        messages: updatedMessages,
        messageCount: updatedMessages.length,
      );
      notifyListeners();

      // Get AI response
      final response = await _aiService.getResponse(content);
      final aiMessage = ChatMessage.createAIMessage(response);

      // Update session with AI message
      final finalMessages = [...updatedMessages, aiMessage];
      _currentSession = _currentSession!.copyWith(
        messages: finalMessages,
        messageCount: finalMessages.length,
      );
      notifyListeners();

      // Save session
      await _storageService.saveChatSession(_currentSession!);
      if (kDebugMode) {
        print('Updated session ${_currentSession!.id} with new messages');
      }

      // Check if we need to summarize
      if (finalMessages.length >= _summarizeAfterMessages &&
          (_currentSession!.lastSummarized == null ||
              DateTime.now()
                      .difference(_currentSession!.lastSummarized!)
                      .inMinutes >
                  30)) {
        await _updateSummary();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in chat interaction: $e');
      }
    }
  }

  Future<void> _updateSummary() async {
    try {
      final summary = await _aiService.generateSummary(
        messages.map((m) => m.content).toList(),
      );
      await _storageService.updateSessionSummary(_currentSession!.id, summary);
      if (kDebugMode) {
        print('Updated summary for session ${_currentSession!.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating summary: $e');
      }
    }
  }

  @override
  Future<void> clearChat() async {
    try {
      // This will create a new session for today
      await _loadCurrentSession();
      notifyListeners();
      if (kDebugMode) {
        print('Cleared chat and created new session');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing chat: $e');
      }
    }
  }
}
