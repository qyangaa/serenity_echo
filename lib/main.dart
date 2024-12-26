import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/speech_service.dart';
import 'services/chat_service.dart';
import 'services/firebase_storage_service.dart';
import 'services/openai_service.dart';
import 'services/interfaces/storage_service_interface.dart';
import 'services/interfaces/ai_service_interface.dart';
import 'ui/screens/chat_journal_screen.dart';

// TODO: Replace with proper authentication
const String _devUserId = 'dev_user_123';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SpeechService>(
          create: (_) => SpeechService(),
        ),
        Provider<IStorageService>(
          create: (_) => FirestoreStorageService(userId: _devUserId),
        ),
        Provider<IAIService>(
          create: (_) => OpenAIService(),
        ),
        ChangeNotifierProxyProvider2<IStorageService, IAIService, ChatService>(
          create: (context) => ChatService(
            storageService: context.read<IStorageService>(),
            aiService: context.read<IAIService>(),
          ),
          update: (_, storageService, aiService, previous) => previous!
            ..updateDependencies(
              storageService: storageService,
              aiService: aiService,
            ),
        ),
      ],
      child: MaterialApp(
        title: 'SerenityEcho',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SerenityEcho'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.teal,
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to SerenityEcho',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your AI-powered journaling companion',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatJournalScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Start Journaling'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement journal history
        },
        tooltip: 'Journal History',
        child: const Icon(Icons.history),
      ),
    );
  }
}
