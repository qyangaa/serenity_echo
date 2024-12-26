import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_session.dart';
import 'interfaces/storage_service_interface.dart';

class FirestoreStorageService implements IStorageService {
  final FirebaseFirestore _firestore;
  final String userId;
  static const int _maxSessionSize = 500; // Maximum messages per session

  FirestoreStorageService({
    FirebaseFirestore? firestore,
    required this.userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveChatSession(ChatSession session) async {
    if (session.messages.length > _maxSessionSize) {
      throw Exception(
          'Session exceeds maximum size of $_maxSessionSize messages');
    }

    final sessionRef = session.id.isEmpty
        ? _firestore
            .collection('users')
            .doc(userId)
            .collection('chat_sessions')
            .doc()
        : _firestore
            .collection('users')
            .doc(userId)
            .collection('chat_sessions')
            .doc(session.id);

    final updatedSession = session.copyWith(
      id: sessionRef.id,
      updated: DateTime.now(),
      messageCount: session.messages.length,
    );

    await sessionRef.set(updatedSession.toJson());
  }

  @override
  Future<ChatSession?> loadCurrentSession() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .orderBy('updated', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    final doc = querySnapshot.docs.first;
    return ChatSession.fromJson(doc.id, doc.data());
  }

  @override
  Future<List<ChatSession>> loadAllSessions() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .orderBy('updated', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => ChatSession.fromJson(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc(sessionId)
        .delete();
  }

  @override
  Future<void> updateSessionSummary(String sessionId, String summary) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc(sessionId)
        .update({
      'historySummary': summary,
      'lastSummarized': DateTime.now().toIso8601String(),
    });
  }
}
