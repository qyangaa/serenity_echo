import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final String content;
  final DateTime timestamp;
  final Map<String, double>? emotions;
  final String? aiSummary;
  final String? aiSuggestion;

  JournalEntry({
    required this.id,
    required this.content,
    required this.timestamp,
    this.emotions,
    this.aiSummary,
    this.aiSuggestion,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp,
      'emotions': emotions,
      'aiSummary': aiSummary,
      'aiSuggestion': aiSuggestion,
    };
  }

  // Create from Firestore document
  factory JournalEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      emotions: Map<String, double>.from(data['emotions'] ?? {}),
      aiSummary: data['aiSummary'],
      aiSuggestion: data['aiSuggestion'],
    );
  }

  // Create a new entry
  factory JournalEntry.create({
    required String content,
    Map<String, double>? emotions,
    String? aiSummary,
    String? aiSuggestion,
  }) {
    return JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      emotions: emotions,
      aiSummary: aiSummary,
      aiSuggestion: aiSuggestion,
    );
  }
}
