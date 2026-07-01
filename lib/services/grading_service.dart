import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/models/grade_model.dart';
import 'package:alara/core/models/assessment_model.dart';
import 'package:alara/services/terminal_report_service.dart';
import 'package:alara/core/services/notification_service.dart';

const Map<String, double> assessmentTypeMaxScores = {
  'exam': 100,
  'test': 40,
  'quiz': 20,
  'continuous': 30,
  'assignment': 10,
};

// =======================================================================
// HELPER CLASSES (defined before use)
// =======================================================================

class AssessmentsByCategory {
  final List<Assessment> continuousAssessments;
  final List<Assessment> examinations;

  AssessmentsByCategory({
    required this.continuousAssessments,
    required this.examinations,
  });

  List<Assessment> get all => [...continuousAssessments, ...examinations];
}

class ScoreEntry {
  final int studentId;
  final String studentName;
  final double score;

  ScoreEntry({
    required this.studentId,
    required this.studentName,
    required this.score,
  });
}

/// Legacy: Single grade submission (for old UI)
class LegacyGradeSubmission {
  final int studentId;
  final String studentName;
  final double score;
  final int? existingId;

  LegacyGradeSubmission({
    required this.studentId,
    required this.studentName,
    required this.score,
    this.existingId,
  });
}

/// Legacy: Bulk grade result (for old UI)
class LegacyBulkGradeResult {
  final int successCount;
  final int errorCount;
  final List<GradeRecord> grades;
  final List<String> errors;

  LegacyBulkGradeResult({
    required this.successCount,
    required this.errorCount,
    required this.grades,
    required this.errors,
  });
}

// =======================================================================
// GRADING SERVICE
// =======================================================================

class GradingService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();
  final TerminalReportService _terminalService = TerminalReportService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =======================================================================
  // ACADEMIC SESSIONS
  // =======================================================================

  /// Get all academic sessions for the user's school
  Future<List<Map<String, dynamic>>> getAcademicSessions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/academics/academic-sessions/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Academic Sessions Error: $e');
      return [];
    }
  }

  // =======================================================================
  // CLASSES
  // =======================================================================

  /// Fetch all classes assigned to the teacher
  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/students/my_classes/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      debugPrint('Classes API Error: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Classes Service Error: $e');
      return [];
    }
  }

  /// Get grade entry data: students + subjects for a class
  Future<GradeEntryData?> getGradeEntryData(int classId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/grades/grade_entry_data/?class_id=$classId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GradeEntryData.fromJson(json);
      }
      debugPrint('Grade Entry Data Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Grade Entry Data Service Error: $e');
      return null;
    }
  }

  // =======================================================================
  // ASSESSMENTS
  // =======================================================================

  /// Get assessments for a class/subject/term grouped by category
  Future<AssessmentsByCategory> getAssessmentsForClassSubject({
    required int classId,
    required int subjectId,
    int? term,
    int? academicSessionId,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'class_id': classId.toString(),
        'subject_id': subjectId.toString(),
      };
      if (term != null) queryParams['term'] = term.toString();
      if (academicSessionId != null) {
        queryParams['academic_session_id'] = academicSessionId.toString();
      }

      final uri = Uri.parse('$baseUrl/api/academics/grading-assessments/by_class_subject_term/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return AssessmentsByCategory(
          continuousAssessments: (json['continuous_assessments'] as List? ?? [])
              .map((a) => Assessment.fromJson(a))
              .toList(),
          examinations: (json['examinations'] as List? ?? [])
              .map((a) => Assessment.fromJson(a))
              .toList(),
        );
      }
      debugPrint('Assessments Error: ${response.statusCode} - ${response.body}');
      return AssessmentsByCategory(continuousAssessments: [], examinations: []);
    } catch (e) {
      debugPrint('Assessments Service Error: $e');
      return AssessmentsByCategory(continuousAssessments: [], examinations: []);
    }
  }

  /// Create a new assessment
  Future<Assessment?> createAssessment(Map<String, dynamic> assessmentData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/grading-assessments/'),
        headers: headers,
        body: jsonEncode(assessmentData),
      );
      if (response.statusCode == 201) {
        return Assessment.fromJson(jsonDecode(response.body));
      }
      debugPrint('Create Assessment Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Create Assessment Error: $e');
      return null;
    }
  }

  /// Delete an assessment
  Future<bool> deleteAssessment(int assessmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/academics/grading-assessments/$assessmentId/'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete Assessment Error: $e');
      return false;
    }
  }

  // =======================================================================
  // SCORE ENTRY / BULK SAVE
  // =======================================================================

  /// Get scores for a specific assessment (students + existing scores)
  Future<AssessmentScoresResponse?> getAssessmentScores(int assessmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/academics/grading-assessments/assessment_scores/?assessment_id=$assessmentId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return AssessmentScoresResponse.fromJson(jsonDecode(response.body));
      }
      debugPrint('Assessment Scores Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Assessment Scores Service Error: $e');
      return null;
    }
  }

  /// Bulk save scores for all students in an assessment
  Future<BulkScoreResult> bulkSaveScores({
    required int assessmentId,
    required List<ScoreEntry> scores,
  }) async {
    try {
      final headers = await _getHeaders();
      final payload = {
        'scores': scores.map((s) => {
          'student_id': s.studentId,
          'score': s.score,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/grading-assessments/$assessmentId/bulk_save_scores/'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final result = BulkScoreResult.fromJson(jsonDecode(response.body));
        await NotificationService.instance.showLocalNotification(
          title: 'Grading Updated',
          body: '${result.successCount} score(s) saved successfully.',
          type: AppNotificationType.grading,
          payload: {
            'type': 'grading',
            'assessment_id': assessmentId,
            'success_count': result.successCount,
            'error_count': result.errorCount,
          },
        );
        return result;
      }
      debugPrint('Bulk Save Scores Error: ${response.statusCode} - ${response.body}');
      return BulkScoreResult(
        assessmentId: assessmentId,
        assessmentTitle: '',
        results: [],
        errors: [{'error': 'Server error: ${response.statusCode}'}],
        successCount: 0,
        errorCount: 1,
      );
    } catch (e) {
      debugPrint('Bulk Save Scores Service Error: $e');
      return BulkScoreResult(
        assessmentId: assessmentId,
        assessmentTitle: '',
        results: [],
        errors: [{'error': e.toString()}],
        successCount: 0,
        errorCount: 1,
      );
    }
  }

  // =======================================================================
  // COMPUTED RESULTS (per-subject)
  // =======================================================================

  /// Compute final scores with grades, remarks, and positions
  Future<ComputedResults?> computeResults({
    required int classId,
    required int subjectId,
    int? academicSessionId,
    int? term,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'class_id': classId.toString(),
        'subject_id': subjectId.toString(),
      };
      if (academicSessionId != null) {
        queryParams['academic_session_id'] = academicSessionId.toString();
      }
      if (term != null) queryParams['term'] = term.toString();

      final uri = Uri.parse('$baseUrl/api/academics/grading-assessments/compute_results/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return ComputedResults.fromJson(jsonDecode(response.body));
      }
      debugPrint('Compute Results Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Compute Results Error: $e');
      return null;
    }
  }

  // =======================================================================
  // GRADING SCALE - grade boundaries set by school admin
  // =======================================================================

  /// Get the active grading scale for the session
  Future<GradingSystemInfo?> getActiveGradingScale(int? sessionId) async {
    try {
      final headers = await _getHeaders();
      final query = <String, String>{};
      if (sessionId != null) query['session_id'] = sessionId.toString();

      final uri = Uri.parse('$baseUrl/api/academics/grading-scales/active/')
          .replace(queryParameters: query.isNotEmpty ? query : null);

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Response could be a single item or list (paginated or not)
        final results = data['results'] as List? ?? (data is List ? data : [data]);
        if (results.isNotEmpty && results.first is Map<String, dynamic>) {
          return GradingSystemInfo.fromJson(results.first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Grading Scale Error: $e');
      return null;
    }
  }

  // =======================================================================
  // CLASS TERMINAL REPORTS (class-wide positions, promotion, best subject)
  // =======================================================================

  /// Get class-wide terminal reports with positions, promotion, etc.
  Future<TerminalReportsData> getClassTerminalReports({
    required int classId,
    int? sessionId,
  }) async {
    try {
      return await _terminalService.getClassReports(
        classId: classId,
        sessionId: sessionId,
      );
    } catch (e) {
      debugPrint('Class Reports Error: $e');
      rethrow;
    }
  }

  /// Compute class-wide terminal reports for all students
  Future<Map<String, dynamic>> computeClassTerminalReports({
    required int classId,
    required int sessionId,
  }) async {
    try {
      return await _terminalService.computeClassReports(
        classId: classId,
        sessionId: sessionId,
      );
    } catch (e) {
      debugPrint('Compute Class Reports Error: $e');
      rethrow;
    }
  }

  // =======================================================================
  // LEGACY METHODS (kept for backward compatibility)
  // =======================================================================

  Future<List<GradeRecord>> getExistingGrades({
    required int classId,
    int? subjectId,
    String? assessmentType,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/api/students/grades/?class_id=$classId';
      if (subjectId != null) url += '&subject_id=$subjectId';
      if (assessmentType != null) url += '&assessment_type=$assessmentType';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? data as List? ?? [];
        return results.map((g) => GradeRecord.fromJson(g)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get Grades Error: $e');
      return [];
    }
  }

  Future<List<GradeRecord>> getGradeHistory({
    int? classId,
    int? subjectId,
    int? studentId,
    String? assessmentType,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final query = <String, String>{};
      if (classId != null) query['class_id'] = classId.toString();
      if (subjectId != null) query['subject_id'] = subjectId.toString();
      if (studentId != null) query['student_id'] = studentId.toString();
      if (assessmentType != null && assessmentType.isNotEmpty) {
        query['assessment_type'] = assessmentType;
      }
      if (fromDate != null && fromDate.isNotEmpty) query['from_date'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) query['to_date'] = toDate;

      final uri = Uri.parse('$baseUrl/api/students/grades/history/').replace(
        queryParameters: query.isEmpty ? null : query,
      );

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        return results.map((g) => GradeRecord.fromJson(g)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get Grade History Error: $e');
      return [];
    }
  }

  Future<GradeRecord?> submitGrade(GradeRecord grade) async {
    try {
      final headers = await _getHeaders();
      final body = grade.toJson();

      http.Response response;
      if (grade.id == 0) {
        response = await http.post(
          Uri.parse('$baseUrl/api/students/grades/'),
          headers: headers,
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse('$baseUrl/api/students/grades/${grade.id}/'),
          headers: headers,
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return GradeRecord.fromJson(jsonDecode(response.body));
      }
      debugPrint('Submit Grade Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Submit Grade Error: $e');
      return null;
    }
  }

  Future<LegacyBulkGradeResult> bulkSubmitGrades({
    required int subjectId,
    required String assessmentType,
    required List<LegacyGradeSubmission> submissions,
    String? recordedDate,
  }) async {
    final results = <GradeRecord>[];
    final errors = <String>[];

    for (final sub in submissions) {
      final maxScore = assessmentTypeMaxScores[assessmentType] ?? 100;
      final grade = GradeRecord(
        id: sub.existingId ?? 0,
        student: sub.studentId,
        subject: subjectId,
        assessmentType: assessmentType,
        score: sub.score,
        maxScore: maxScore,
        recordedDate: recordedDate,
      );

      final result = await submitGrade(grade);
      if (result != null) {
        results.add(result);
      } else {
        errors.add('Student ${sub.studentName}: Failed to submit');
      }
    }

    return LegacyBulkGradeResult(
      successCount: results.length,
      errorCount: errors.length,
      grades: results,
      errors: errors,
    );
  }
}
