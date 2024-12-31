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
      if (kDebugMode) {
        print('\n=== Loading Chat Session ===');
      }

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
          print('Message count: ${_currentSession?.messages.length}');
          if (_currentSession?.messages.isNotEmpty ?? false) {
            print('\nLast 3 messages:');
            final lastMessages =
                _currentSession!.messages.reversed.take(3).toList().reversed;
            for (var m in lastMessages) {
              print('${m.isUser ? "User" : "AI"}: ${m.content}');
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current session: $e');
      }
    } finally {
      if (kDebugMode) {
        print('===========================\n');
      }
      _isLoading = false;
    }
  }

  @override
  List<ChatMessage> get messages => _currentSession?.messages ?? [];

  @override
  Future<void> addUserMessage(String content) async {
    try {
      if (kDebugMode) {
        print('\n=== Processing User Message ===');
        print('Content: $content');
      }

      // First, moderate the content
      final isContentSafe = await _moderateContent(content);
      if (!isContentSafe) {
        if (kDebugMode) {
          print('Content moderation failed - message rejected');
        }
        final aiMessage = ChatMessage.createAIMessage(
          'I apologize, but I cannot process that content. Please ensure your message follows our community guidelines.',
        );
        _currentSession = _currentSession?.copyWith(
          messages: [...(_currentSession?.messages ?? []), aiMessage],
          messageCount: (_currentSession?.messageCount ?? 0) + 1,
          summary: _currentSession?.summary ?? '',
          lastSummarized: _currentSession?.lastSummarized,
        );
        notifyListeners();
        return;
      }

      if (_currentSession == null) {
        if (kDebugMode) {
          print('No active session, loading...');
        }
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
        summary: _currentSession!.summary,
        lastSummarized: _currentSession!.lastSummarized,
      );
      notifyListeners();

      if (kDebugMode) {
        print('\nGetting AI response...');
      }

      // Get AI response
      final response = await _aiService.getResponse(content);
      final aiMessage = ChatMessage.createAIMessage(response);

      // Update session with AI message
      final finalMessages = [...updatedMessages, aiMessage];
      _currentSession = _currentSession!.copyWith(
        messages: finalMessages,
        messageCount: finalMessages.length,
        summary: _currentSession!.summary,
        lastSummarized: _currentSession!.lastSummarized,
      );
      notifyListeners();

      // Save session
      await _storageService.saveChatSession(_currentSession!);
      if (kDebugMode) {
        print('Updated session ${_currentSession!.id} with new messages');
        print('Current message count: ${finalMessages.length}');
      }

      // Generate summary after every message for debugging
      if (kDebugMode) {
        print('\nGenerating debug summary after message...');
      }
      await _updateSummary();
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
        summary: _currentSession?.summary ?? '',
        lastSummarized: _currentSession?.lastSummarized,
      );
      notifyListeners();
    } finally {
      if (kDebugMode) {
        print('=============================\n');
      }
    }
  }

  Future<void> _updateSummary() async {
    try {
      if (kDebugMode) {
        print('\n=== Updating Summary ===');
        print('Messages to summarize: ${messages.length}');
        print('Last summarized: ${_currentSession?.lastSummarized}');
        print(
            'Time since last summary: ${_currentSession?.lastSummarized != null ? DateTime.now().difference(_currentSession!.lastSummarized!).inMinutes : "never"} minutes');
      }

      final summary = await _aiService.generateSummary(
        messages
            .map((m) => '${m.isUser ? "User" : "AI"}: ${m.content}')
            .toList(),
      );

      if (kDebugMode) {
        print('\nGenerated Summary:');
        print(summary);
      }

      await _storageService.updateSessionSummary(_currentSession!.id, summary);

      // Update lastSummarized timestamp
      _currentSession = _currentSession!.copyWith(
        lastSummarized: DateTime.now(),
        summary: summary,
      );
      await _storageService.saveChatSession(_currentSession!);

      if (kDebugMode) {
        print('\nSummary saved for session ${_currentSession!.id}');
        print('Summary length: ${summary.length} characters');
        print(
            'Next summary will be generated after: ${_currentSession!.lastSummarized!.add(Duration(minutes: 30))}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating summary: $e');
      }
    } finally {
      if (kDebugMode) {
        print('=======================\n');
      }
    }
  }

  Future<void> createNewSession() async {
    try {
      if (kDebugMode) {
        print('\n=== Creating New Session ===');
      }

      // Save current session if it exists
      if (_currentSession != null) {
        await _storageService.saveChatSession(_currentSession!);
        if (kDebugMode) {
          print('Saved current session: ${_currentSession?.id}');
        }
      }

      // Create a new empty session
      _currentSession = ChatSession.create();
      // Save it to get an ID
      await _storageService.saveChatSession(_currentSession!);

      if (kDebugMode) {
        print('Created new session with ID: ${_currentSession?.id}');
      }

      // Force refresh of UI
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error creating new session: $e');
      }
    } finally {
      if (kDebugMode) {
        print('===========================\n');
      }
    }
  }

  @override
  Future<void> clearChat() async {
    try {
      if (kDebugMode) {
        print('\n=== Clearing Chat ===');
      }

      // Create a new session
      await createNewSession();

      if (kDebugMode) {
        print('Chat cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing chat: $e');
      }
    } finally {
      if (kDebugMode) {
        print('===========================\n');
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
