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
      // First, moderate the content
      final isContentSafe = await _moderateContent(content);
      if (!isContentSafe) {
        final aiMessage = ChatMessage.createAIMessage(
          'I apologize, but I cannot process that content. Please ensure your message follows our community guidelines.',
        );
        _currentSession = _currentSession?.copyWith(
          messages: [...(_currentSession?.messages ?? []), aiMessage],
          messageCount: (_currentSession?.messageCount ?? 0) + 1,
        );
        notifyListeners();
        return;
      }

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
      // Add error message to chat
      final errorMessage = ChatMessage.createAIMessage(
        'I apologize, but I encountered an error. Please try again.',
      );
      _currentSession = _currentSession?.copyWith(
        messages: [...(_currentSession?.messages ?? []), errorMessage],
        messageCount: (_currentSession?.messageCount ?? 0) + 1,
      );
      notifyListeners();
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

  @override
  Future<List<String>> generateFollowUpQuestions() async {
    try {
      if (_currentSession == null || _currentSession!.messages.isEmpty) {
        return [];
      }
      return await _aiService
          .generateFollowUpQuestions(_currentSession!.messages);
    } catch (e) {
      if (kDebugMode) {
        print('Error generating follow-up questions: $e');
      }
      return [];
    }
  }

  @override
  Future<Map<String, double>> analyzeEmotions(String message) async {
    try {
      return await _aiService.analyzeEmotion(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing emotions: $e');
      }
      return {
        'joy': 0.0,
        'sadness': 0.0,
        'anger': 0.0,
        'fear': 0.0,
        'surprise': 0.0,
        'love': 0.0,
      };
    }
  }

  @override
  Future<String> generateReflectionPrompt() async {
    try {
      if (_currentSession == null || _currentSession!.messages.isEmpty) {
        return 'What would you like to reflect on today?';
      }
      return await _aiService
          .generateReflectionPrompt(_currentSession!.messages);
    } catch (e) {
      if (kDebugMode) {
        print('Error generating reflection prompt: $e');
      }
      return 'What was the most meaningful part of your day?';
    }
  }

  Future<bool> _moderateContent(String content) async {
    try {
      return await _aiService.moderateContent(content);
    } catch (e) {
      if (kDebugMode) {
        print('Error moderating content: $e');
      }
      return true; // Default to allowing content if moderation fails
    }
  }
}
