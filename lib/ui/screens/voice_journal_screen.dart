import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/speech_service.dart';

class VoiceJournalScreen extends StatefulWidget {
  const VoiceJournalScreen({super.key});

  @override
  State<VoiceJournalScreen> createState() => _VoiceJournalScreenState();
}

class _VoiceJournalScreenState extends State<VoiceJournalScreen> {
  late SpeechService _speechService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _speechService = Provider.of<SpeechService>(context, listen: false);
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
        title: const Text('Voice Journal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Consumer<SpeechService>(
                  builder: (context, speechService, _) {
                    return SingleChildScrollView(
                      child: Text(
                        speechService.text.isEmpty
                            ? 'Start speaking to begin journaling...'
                            : speechService.text,
                        style: TextStyle(
                          fontSize: 18,
                          color: speechService.text.isEmpty
                              ? Colors.grey[600]
                              : Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Consumer<SpeechService>(
              builder: (context, speechService, _) {
                return Column(
                  children: [
                    if (speechService.text.isNotEmpty) ...[
                      ElevatedButton(
                        onPressed: () {
                          speechService.clearText();
                        },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FloatingActionButton.large(
                      onPressed: !_isInitialized
                          ? null
                          : () async {
                              if (speechService.isListening) {
                                await speechService.stopListening();
                              } else {
                                await speechService.startListening();
                              }
                            },
                      backgroundColor: speechService.isListening
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                      child: Icon(
                        speechService.isListening ? Icons.stop : Icons.mic,
                        size: 32,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
