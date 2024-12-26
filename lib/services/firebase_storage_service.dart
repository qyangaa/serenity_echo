import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import 'interfaces/storage_service_interface.dart';

class FirestoreStorageService implements IStorageService {
  final FirebaseFirestore _firestore;
  final String userId;

  FirestoreStorageService({
    FirebaseFirestore? firestore,
    required this.userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveChatSession(List<ChatMessage> messages) async {
    final batch = _firestore.batch();
    final sessionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc();

    batch.set(sessionRef, {
      'timestamp': FieldValue.serverTimestamp(),
      'messageCount': messages.length,
    });

    for (var message in messages) {
      final messageRef = sessionRef.collection('messages').doc();
      batch.set(messageRef, message.toJson());
    }

    await batch.commit();
  }

  @override
  Future<List<ChatMessage>> loadChatSessions() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return [];
    }

    final sessionDoc = querySnapshot.docs.first;
    final messagesSnapshot = await sessionDoc.reference
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return messagesSnapshot.docs
        .map((doc) => ChatMessage.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> deleteChatSession(String sessionId) async {
    final sessionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc(sessionId);

    final messagesSnapshot = await sessionRef.collection('messages').get();
    final batch = _firestore.batch();

    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(sessionRef);
    await batch.commit();
  }
}
