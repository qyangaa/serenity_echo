import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/speech_service.dart';

class ChatJournalScreen extends StatefulWidget {
  const ChatJournalScreen({super.key});

  @override
  State<ChatJournalScreen> createState() => _ChatJournalScreenState();
}

class _ChatJournalScreenState extends State<ChatJournalScreen> {
  late SpeechService _speechService;
  late ChatService _chatService;
  bool _isInitialized = false;
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    _speechService = Provider.of<SpeechService>(context, listen: false);
    _chatService = Provider.of<ChatService>(context, listen: false);
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechService.initialize();
    setState(() {
      _isInitialized = available;
    });
  }

  Future<void> _analyzeEmotions(String message) async {
    try {
      await _chatService.analyzeEmotions(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing emotions: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _chatService.clearChat();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showDebugInfo)
              Consumer<ChatService>(
                builder: (context, chatService, _) {
                  return Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Summary:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(chatService.currentSummary ?? 'No summary yet'),
                        if (chatService.lastSummarized != null)
                          Text(
                            'Last Updated: ${chatService.lastSummarized!.toLocal()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  );
                },
              ),
            Expanded(
              child: Consumer<ChatService>(
                builder: (context, chatService, _) {
                  final messages = chatService.messages
                      .map((msg) => msg.toChatUIMessage())
                      .toList();

                  return Chat(
                    messages: messages.reversed.toList(),
                    onSendPressed: _handleSendPressed,
                    user: const types.User(id: 'user'),
                    showUserAvatars: false,
                    showUserNames: false,
                    theme: DefaultChatTheme(
                      primaryColor: Theme.of(context).primaryColor,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      inputBackgroundColor: Colors.grey[200]!,
                      inputTextColor: Colors.black87,
                      inputBorderRadius: BorderRadius.circular(25),
                      messageBorderRadius: 20,
                      messageInsetsHorizontal: 16,
                      messageInsetsVertical: 12,
                    ),
                  );
                },
              ),
            ),
            Consumer<SpeechService>(
              builder: (context, speechService, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            speechService.text.isEmpty
                                ? 'Tap mic to start speaking...'
                                : speechService.text,
                            style: TextStyle(
                              color: speechService.text.isEmpty
                                  ? Colors.grey[600]
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        onPressed: !_isInitialized
                            ? null
                            : () async {
                                if (speechService.isListening) {
                                  await speechService.stopListening();
                                  if (speechService.text.isNotEmpty) {
                                    final text = speechService.text;
                                    await _chatService.addUserMessage(text);
                                    await _analyzeEmotions(text);
                                    speechService.clearText();
                                  }
                                } else {
                                  await speechService.startListening();
                                }
                              },
                        backgroundColor: speechService.isListening
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        child: Icon(
                          speechService.isListening ? Icons.stop : Icons.mic,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleSendPressed(types.PartialText message) async {
    await _chatService.addUserMessage(message.text);
    await _analyzeEmotions(message.text);
  }
}
