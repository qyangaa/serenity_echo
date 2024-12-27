import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/speech_service.dart';
import 'services/firebase_storage_service.dart';
import 'services/interfaces/storage_service_interface.dart';

// TODO: Replace with proper authentication
const String _devUserId = 'dev_user_123';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
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
              'SerenityEcho',
              key: Key('home_title'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your AI-powered journaling companion',
              key: Key('home_subtitle'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              key: const Key('start_journaling_button'),
              onPressed: () {
                // TODO: Implement new chat screen with AI Toolkit
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon with AI Toolkit integration!'),
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
