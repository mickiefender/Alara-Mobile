import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';

// ============================================================
// Data Models
// ============================================================

class AiGenerationResult {
  final bool success;
  final String? aiName;
  final List<GeneratedQuestion> questions;
  final int count;
  final String? error;
  final String? rawResponse;

  AiGenerationResult({
    this.success = false,
    this.aiName,
    this.questions = const [],
    this.count = 0,
    this.error,
    this.rawResponse,
  });
}

class GeneratedQuestion {
  final int id;
  final String question;
  final List<String>? options;
  final String? correctAnswer;
  final String? explanation;
  final String? modelAnswer;
  final String? markingScheme;
  final int? marks;
  final int? maxMarks;
  final List<String>? markingPoints;
  final String? answerKey;
  final String? rubric;
  final Map<String, String>? rubricMap;

  GeneratedQuestion({
    this.id = 0,
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.modelAnswer,
    this.markingScheme,
    this.marks,
    this.maxMarks,
    this.markingPoints,
    this.answerKey,
    this.rubric,
    this.rubricMap,
  });

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) {
    List<String>? options;
    if (json['options'] != null && json['options'] is List) {
      options = (json['options'] as List).map((e) => e.toString()).toList();
    }

    Map<String, String>? rubricMap;
    if (json['rubric'] != null && json['rubric'] is Map) {
      rubricMap =
          (json['rubric'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    List<String>? markingPoints;
    if (json['marking_points'] != null && json['marking_points'] is List) {
      markingPoints = (json['marking_points'] as List).map((e) => e.toString()).toList();
    }

    return GeneratedQuestion(
      id: (json['id'] ?? 0) is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      question: json['question']?.toString() ?? '',
      options: options,
      correctAnswer: json['correct_answer']?.toString(),
      explanation: json['explanation']?.toString(),
      modelAnswer: json['model_answer']?.toString(),
      markingScheme: json['marking_scheme']?.toString(),
      marks: json['marks'] is int
          ? json['marks'] as int
          : int.tryParse(json['marks']?.toString() ?? ''),
      maxMarks: json['max_marks'] is int
          ? json['max_marks'] as int
          : int.tryParse(json['max_marks']?.toString() ?? ''),
      markingPoints: markingPoints,
      answerKey: json['answer_key']?.toString(),
      rubric: json['rubric']?.toString(),
      rubricMap: rubricMap,
    );
  }

  String get answerDisplay {
    if (correctAnswer != null) return correctAnswer!;
    if (modelAnswer != null) return modelAnswer!;
    if (answerKey != null) return answerKey!;
    return 'See explanation';
  }

  String get questionTypeLabel {
    if (options != null && options!.isNotEmpty) return 'Multiple Choice';
    if (maxMarks != null && maxMarks! > 10) return 'Essay';
    return 'Short Answer';
  }
}

class DocumentInfo {
  final int id;
  final String title;
  final String? description;
  final String? subjectName;
  final String? className;
  final String? fileUrl;
  final String? uploadedByName;
  final String? createdAt;

  DocumentInfo({
    required this.id,
    required this.title,
    this.description,
    this.subjectName,
    this.className,
    this.fileUrl,
    this.uploadedByName,
    this.createdAt,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      subjectName: json['subject_name']?.toString(),
      className: json['class_name']?.toString(),
      fileUrl: json['file_url']?.toString(),
      uploadedByName: json['uploaded_by_name']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

// ============================================================
// AI Questions Service
// ============================================================

class AiQuestionsService {
  final AuthService _authService = AuthService();
  static String get baseUrl => AuthService.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generate questions from a topic (no document needed)
  Future<AiGenerationResult> generateFromTopic({
    required String topic,
    String subject = '',
    int numQuestions = 5,
    String questionType = 'multiple_choice',
    String difficulty = 'medium',
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/documents/generate_questions_from_topic/'),
        headers: headers,
        body: jsonEncode({
          'topic': topic,
          'subject': subject,
          'num_questions': numQuestions,
          'question_type': questionType,
          'difficulty': difficulty,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('generateFromTopic Error: $e');
      return AiGenerationResult(error: 'Failed to connect to server: $e');
    }
  }

  /// Generate questions from a specific document by ID
  Future<AiGenerationResult> generateFromDocument({
    required int documentId,
    int numQuestions = 5,
    String questionType = 'multiple_choice',
    String difficulty = 'medium',
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/documents/$documentId/generate_questions/'),
        headers: headers,
        body: jsonEncode({
          'num_questions': numQuestions,
          'question_type': questionType,
          'difficulty': difficulty,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('generateFromDocument Error: $e');
      return AiGenerationResult(error: 'Failed to connect to server: $e');
    }
  }

  /// Generate questions from topic + optional document (uses the AI viewset)
  Future<AiGenerationResult> generateQuestions({
    required String topic,
    String subject = '',
    int numQuestions = 5,
    String questionType = 'multiple_choice',
    String difficulty = 'medium',
    int? documentId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'topic': topic,
        'subject': subject,
        'num_questions': numQuestions,
        'question_type': questionType,
        'difficulty': difficulty,
        'is_topic': documentId == null,
      };
      if (documentId != null) {
        body['document_id'] = documentId;
      }

      final String endpoint = documentId != null
          ? '$baseUrl/api/academics/documents/$documentId/generate_questions/'
          : '$baseUrl/api/academics/documents/generate_questions_from_topic/';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('generateQuestions Error: $e');
      return AiGenerationResult(error: 'Failed to connect to server: $e');
    }
  }

  /// Fetch documents (learning materials) for the current teacher
  Future<List<DocumentInfo>> fetchDocuments() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/academics/documents/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results =
            data is List ? data : (data['results'] ?? []);
        return results
            .map((doc) => DocumentInfo.fromJson(doc as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('fetchDocuments Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('fetchDocuments Error: $e');
      return [];
    }
  }

  AiGenerationResult _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return AiGenerationResult(error: data['error'].toString());
      }

      List<GeneratedQuestion> questions = [];
      if (data.containsKey('questions')) {
        final qData = data['questions'];
        if (qData is Map<String, dynamic> && qData.containsKey('questions')) {
          questions = (qData['questions'] as List)
              .map((q) => GeneratedQuestion.fromJson(q as Map<String, dynamic>))
              .toList();
        } else if (qData is List) {
          questions = qData
              .map((q) => GeneratedQuestion.fromJson(q as Map<String, dynamic>))
              .toList();
        }
      }

      return AiGenerationResult(
        success: true,
        aiName: data['ai_name']?.toString(),
        questions: questions,
        count: questions.length,
        rawResponse: data['raw_response'] == true ? data['content']?.toString() : null,
      );
    } else {
      debugPrint('API Error: ${response.statusCode} - ${response.body}');
      String errorMsg = 'Server error (${response.statusCode})';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMsg = errorBody['error'].toString();
        }
      } catch (_) {}
      return AiGenerationResult(error: errorMsg);
    }
  }
}
