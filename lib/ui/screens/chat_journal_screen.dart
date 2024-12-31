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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Session',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New Session'),
                  content: const Text(
                      'Start a new session? This will save your current session and start a fresh one.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Start New'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _chatService.createNewSession();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Started a new session'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
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
                                    await _chatService
                                        .addUserMessage(speechService.text);
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

  void _handleSendPressed(types.PartialText message) {
    _chatService.addUserMessage(message.text);
  }
}
