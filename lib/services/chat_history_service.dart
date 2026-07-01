import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:alara/services/ai_questions_service.dart';

/// Source of the AI question generation
enum GenerationSource { topic, document }

/// Represents a single chat message persisted to storage
class PersistedChatMessage {
  final String text;
  final bool isUser;
  final bool isWelcome;
  final List<PersistedQuestion>? questions;

  PersistedChatMessage({
    required this.text,
    this.isUser = false,
    this.isWelcome = false,
    this.questions,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'isWelcome': isWelcome,
    'questions': questions?.map((q) => q.toJson()).toList(),
  };

  factory PersistedChatMessage.fromJson(Map<String, dynamic> json) => PersistedChatMessage(
    text: json['text'] as String? ?? '',
    isUser: json['isUser'] as bool? ?? false,
    isWelcome: json['isWelcome'] as bool? ?? false,
    questions: (json['questions'] as List<dynamic>?)
        ?.map((q) => PersistedQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
}

/// Lightweight serializable version of GeneratedQuestion
class PersistedQuestion {
  final int id;
  final String question;
  final List<String>? options;
  final String? correctAnswer;
  final String? explanation;
  final String? modelAnswer;
  final int? maxMarks;
  final List<String>? markingPoints;

  PersistedQuestion({
    this.id = 0,
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.modelAnswer,
    this.maxMarks,
    this.markingPoints,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    'modelAnswer': modelAnswer,
    'maxMarks': maxMarks,
    'markingPoints': markingPoints,
  };

  factory PersistedQuestion.fromJson(Map<String, dynamic> json) => PersistedQuestion(
    id: json['id'] as int? ?? 0,
    question: json['question'] as String? ?? '',
    options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    correctAnswer: json['correctAnswer'] as String?,
    explanation: json['explanation'] as String?,
    modelAnswer: json['modelAnswer'] as String?,
    maxMarks: json['maxMarks'] as int?,
    markingPoints: (json['markingPoints'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
  );

  GeneratedQuestion toGeneratedQuestion() => GeneratedQuestion(
    id: id,
    question: question,
    options: options,
    correctAnswer: correctAnswer,
    explanation: explanation,
    modelAnswer: modelAnswer,
    maxMarks: maxMarks,
    markingPoints: markingPoints,
  );
}

/// Represents a complete chat session
class ChatSession {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final int messageCount;
  final int questionCount;
  final List<PersistedChatMessage> messages;
  final GenerationSource source;
  final String? subject;
  final String? difficulty;
  final String? questionType;
  final String? topic;
  final String? documentTitle;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.questionCount = 0,
    this.messages = const [],
    this.source = GenerationSource.topic,
    this.subject,
    this.difficulty,
    this.questionType,
    this.topic,
    this.documentTitle,
  });

  ChatSession copyWith({
    String? title,
    int? updatedAt,
    int? messageCount,
    int? questionCount,
    List<PersistedChatMessage>? messages,
    GenerationSource? source,
    String? subject,
    String? difficulty,
    String? questionType,
    String? topic,
    String? documentTitle,
  }) => ChatSession(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messageCount: messageCount ?? this.messageCount,
    questionCount: questionCount ?? this.questionCount,
    messages: messages ?? this.messages,
    source: source ?? this.source,
    subject: subject ?? this.subject,
    difficulty: difficulty ?? this.difficulty,
    questionType: questionType ?? this.questionType,
    topic: topic ?? this.topic,
    documentTitle: documentTitle ?? this.documentTitle,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'messageCount': messageCount,
    'questionCount': questionCount,
    'messages': messages.map((m) => m.toJson()).toList(),
    'source': source.name,
    'subject': subject,
    'difficulty': difficulty,
    'questionType': questionType,
    'topic': topic,
    'documentTitle': documentTitle,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Untitled',
    createdAt: json['createdAt'] as int? ?? 0,
    updatedAt: json['updatedAt'] as int? ?? 0,
    messageCount: json['messageCount'] as int? ?? 0,
    questionCount: json['questionCount'] as int? ?? 0,
    messages: (json['messages'] as List<dynamic>?)
        ?.map((m) => PersistedChatMessage.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
    source: GenerationSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => GenerationSource.topic,
    ),
    subject: json['subject'] as String?,
    difficulty: json['difficulty'] as String?,
    questionType: json['questionType'] as String?,
    topic: json['topic'] as String?,
    documentTitle: json['documentTitle'] as String?,
  );

  /// Derive a title from the first user message if empty
  String get displayTitle {
    if (title.isNotEmpty && title != 'Untitled') return title;
    if (topic != null && topic!.isNotEmpty) {
      return topic!.length > 50 ? '${topic!.substring(0, 50)}...' : topic!;
    }
    for (final msg in messages) {
      if (msg.isUser && msg.text.isNotEmpty) {
        final clean = msg.text.replaceAll(RegExp(r'[*#]'), '').trim();
        if (clean.isNotEmpty) {
          return clean.length > 50 ? '${clean.substring(0, 50)}...' : clean;
        }
      }
    }
    return 'Untitled Session';
  }

  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Service for persisting AI chat sessions locally
class ChatHistoryService {
  static const _storageKey = 'ai_chat_sessions';
  static const _maxSessions = 50;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Load all saved sessions (metadata only, without full messages)
  Future<List<ChatSession>> loadSessions() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('ChatHistoryService.loadSessions error: $e');
      return [];
    }
  }

  /// Save a session (inserts if new, updates if existing)
  Future<void> saveSession(ChatSession session) async {
    try {
      final sessions = await loadSessions();
      final index = sessions.indexWhere((s) => s.id == session.id);

      if (index >= 0) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session);
      }

      // Keep only the most recent N sessions
      while (sessions.length > _maxSessions) {
        sessions.removeLast();
      }

      await _storage.write(
        key: _storageKey,
        value: jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('ChatHistoryService.saveSession error: $e');
    }
  }

  /// Delete a session by ID
  Future<void> deleteSession(String sessionId) async {
    try {
      final sessions = await loadSessions();
      sessions.removeWhere((s) => s.id == sessionId);
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('ChatHistoryService.deleteSession error: $e');
    }
  }

  /// Clear all session history
  Future<void> clearAll() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (e) {
      debugPrint('ChatHistoryService.clearAll error: $e');
    }
  }

  /// Get only session list (no messages) for history browsing
  Future<List<ChatSession>> loadSessionList() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((j) {
            final session = ChatSession.fromJson(j as Map<String, dynamic>);
            // Return a lightweight copy without messages for the list view
            return session.copyWith(messages: []);
          })
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('ChatHistoryService.loadSessionList error: $e');
      return [];
    }
  }
}
