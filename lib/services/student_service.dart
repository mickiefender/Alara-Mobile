import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/core/models/timetable.dart';
import 'package:alara/core/models/fee.dart';
import 'package:alara/core/models/announcement.dart';
import 'package:alara/core/models/notice.dart';
import 'package:alara/core/services/notification_service.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';

class StudentDashboardData {
  final int totalClasses;
  final int totalSubjects;
  final double attendancePercentage;
  final int pendingAssignments;
  final int totalAssignments;
  final double overallPerformance;
  final int unreadMessages;
  final int unreadAnnouncements;

  StudentDashboardData({
    this.totalClasses = 0,
    this.totalSubjects = 0,
    this.attendancePercentage = 0.0,
    this.pendingAssignments = 0,
    this.totalAssignments = 0,
    this.overallPerformance = 0.0,
    this.unreadMessages = 0,
    this.unreadAnnouncements = 0,
  });

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    return StudentDashboardData(
      totalClasses: json['total_classes'] ?? 0,
      totalSubjects: json['total_subjects'] ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      pendingAssignments: json['pending_assignments'] ?? 0,
      totalAssignments: json['total_assignments'] ?? 0,
      overallPerformance: (json['overall_performance'] as num?)?.toDouble() ?? 0.0,
      unreadMessages: json['unread_messages'] ?? 0,
      unreadAnnouncements: json['unread_announcements'] ?? 0,
    );
  }
}

class StudentSubjectPerformance {
  final String subjectName;
  final double score;
  final double maxScore;
  final String grade;
  final int? position;

  StudentSubjectPerformance({
    required this.subjectName,
    required this.score,
    required this.maxScore,
    required this.grade,
    this.position,
  });

  factory StudentSubjectPerformance.fromJson(Map<String, dynamic> json) {
    return StudentSubjectPerformance(
      subjectName: json['subject_name'] ?? json['name'] ?? '',
      score: (json['score'] ?? json['total_score'] ?? 0).toDouble(),
      maxScore: (json['max_score'] ?? 100).toDouble(),
      grade: json['grade'] ?? '',
      position: json['position'] ?? json['subject_position'] ?? json['rank'],
    );
  }
}

class StudentAssignment {
  final String id;
  final String title;
  final String description;
  final String subjectName;
  final DateTime dueDate;
  final String? submissionStatus;
  final double? score;
  final String? feedback;
  final bool isSubmitted;

  StudentAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.dueDate,
    this.submissionStatus,
    this.score,
    this.feedback,
    this.isSubmitted = false,
  });

  bool get isOverdue => !isSubmitted && DateTime.now().isAfter(dueDate);

  factory StudentAssignment.fromJson(Map<String, dynamic> json) {
    final assignment = json['assignment'] ?? json;
    final submission = json['submission'];
    return StudentAssignment(
      id: assignment['id'].toString(),
      title: assignment['title'] ?? '',
      description: assignment['description'] ?? '',
      subjectName: assignment['subject_name'] ?? '',
      dueDate: DateTime.tryParse(assignment['due_date'] ?? '') ?? DateTime.now(),
      submissionStatus: submission?['status'],
      score: (submission?['score'] as num?)?.toDouble(),
      feedback: submission?['feedback']?.toString(),
      isSubmitted: submission != null && submission['status'] != 'not_submitted',
    );
  }
}

class StudentAiResponse {
  final bool success;
  final String message;
  final String? error;
  final List<String> questions;

  StudentAiResponse({
    required this.success,
    required this.message,
    this.error,
    this.questions = const [],
  });
}

class StudentService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<User?> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }

  String _studentScopeKey(dynamic studentId) {
    if (studentId == null) return 'unknown';
    final normalized = studentId.toString().trim();
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  String _cacheKeyDashboard(dynamic studentId) => 'student_dashboard:${_studentScopeKey(studentId)}';
  String _cacheKeyClasses(dynamic studentId) => 'class:student_classes:${_studentScopeKey(studentId)}';
  String _cacheKeyTimetable(dynamic studentId) => 'timetable:student:${_studentScopeKey(studentId)}';
  String _cacheKeyResults(dynamic studentId) => 'result:student:${_studentScopeKey(studentId)}';
  String _cacheKeyAssignments(dynamic studentId) => 'assessment:assignments:${_studentScopeKey(studentId)}';
  String _cacheKeyMaterials(dynamic studentId) => 'material:student:${_studentScopeKey(studentId)}';
  String _cacheKeyAttendanceReport(dynamic studentId) => 'attendance:report:${_studentScopeKey(studentId)}';
  String _cacheKeyAttendanceHistory(dynamic studentId) => 'attendance:history:${_studentScopeKey(studentId)}';
  String _cacheKeyAnnouncements(dynamic studentId) => 'announcement:student:${_studentScopeKey(studentId)}';
  String _cacheKeyNotices(dynamic studentId) => 'announcement:notices:${_studentScopeKey(studentId)}';
  String _cacheKeyPersonalNotices(dynamic studentId) => 'announcement:personal_notices:${_studentScopeKey(studentId)}';
  String _cacheKeyFees(dynamic studentId) => 'assessment:fees:${_studentScopeKey(studentId)}';

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map<String, dynamic>) {
      if (raw['results'] is List) {
        final results = raw['results'] as List;
        return results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [raw];
    }
    return <Map<String, dynamic>>[];
  }

// ─── Dashboard Overview ─────────────────────────────────────────

  /// Unified dashboard data from optimized endpoint
  Future<Map<String, dynamic>> getUnifiedDashboard() async {
    try {
      final headers = await _getHeaders();
      final cacheKey = 'student_dashboard:unified';
      
      // Use unified endpoint with caching (5 min TTL)
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/student-portal/dashboard/'),
        headers: headers,
      );
      
      if (response.statusCode != 200) {
        debugPrint('Dashboard endpoint error: ${response.statusCode}');
        return {};
      }
      
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Unified Dashboard Error: $e');
      return {};
    }
  }

  Future<StudentDashboardData> getDashboardData() async {
    try {
      // Try the new unified endpoint first
      final unifiedData = await getUnifiedDashboard();
      
      if (unifiedData.isNotEmpty) {
        // Parse data from unified endpoint
        final attendance = unifiedData['attendance'] as Map<String, dynamic>? ?? {};
        final performance = unifiedData['performance'] as Map<String, dynamic>? ?? {};
        
        return StudentDashboardData(
          totalClasses: unifiedData['total_classes'] as int? ?? 0,
          totalSubjects: unifiedData['total_subjects'] as int? ?? 0,
          attendancePercentage: (attendance['presence_percentage'] as num?)?.toDouble() ?? 0.0,
          pendingAssignments: unifiedData['pending_assignments'] as int? ?? 0,
          totalAssignments: unifiedData['total_assignments'] as int? ?? 0,
          overallPerformance: (performance['overall'] as num?)?.toDouble() ?? 0.0,
        );
      }
      
      // Fallback to old multi-request method
      final user = await getCurrentUser();
      final headers = await _getHeaders();
      final cacheKey = _cacheKeyDashboard(user?.id);

      final payload = await offlineFirstRead(
        cacheKey: cacheKey,
        fetchFn: () async {
          final attendanceFuture = http.get(
            Uri.parse('$baseUrl/api/students/student-portal/attendance_report/'),
            headers: headers,
          );
          final assignmentsFuture = http.get(
            Uri.parse('$baseUrl/api/students/student-portal/assignments/'),
            headers: headers,
          );
          final gradesFuture = http.get(
            Uri.parse('$baseUrl/api/students/grades/?student=${user?.id ?? ''}'),
            headers: headers,
          );

          final results = await Future.wait([attendanceFuture, assignmentsFuture, gradesFuture]);

          final attendanceRes = results[0];
          final assignmentsRes = results[1];
          final gradesRes = results[2];

          final attendanceData = attendanceRes.statusCode == 200
              ? jsonDecode(attendanceRes.body) as Map<String, dynamic>
              : <String, dynamic>{};
          final assignmentsData = assignmentsRes.statusCode == 200
              ? _extractAssignmentsFromPayload(jsonDecode(assignmentsRes.body))
              : <dynamic>[];
          final gradesData = gradesRes.statusCode == 200
              ? jsonDecode(gradesRes.body) as Map<String, dynamic>
              : <String, dynamic>{};

          final myClasses = await getMyClasses();

          return {
            'attendance': attendanceData,
            'assignments': assignmentsData,
            'grades': gradesData,
            'classes': myClasses,
          };
        },
      );

      if (payload == null) return StudentDashboardData();

      final attendanceData = payload['attendance'] is Map<String, dynamic>
          ? payload['attendance'] as Map<String, dynamic>
          : <String, dynamic>{};

      final assignmentsData = payload['assignments'] as List? ?? <dynamic>[];

      final gradesData = payload['grades'] is Map<String, dynamic>
          ? payload['grades'] as Map<String, dynamic>
          : <String, dynamic>{};

      final classesData = _toMapList(payload['classes']);
      final assignedClass = classesData.isNotEmpty ? classesData.first : null;
      final assignedClassSubjects = assignedClass?['subjects'] as List<dynamic>? ?? <dynamic>[];

      final attendancePct = (attendanceData['presence_percentage'] as num?)?.toDouble() ?? 0.0;
      final totalAssignments = assignmentsData.length;
      final pendingAssignments = assignmentsData.where((a) {
        final sub = (a as Map<String, dynamic>)['submission'];
        return sub == null || sub['status'] == 'not_submitted';
      }).length;

      double overallPerf = 0.0;
      final grades = gradesData['results'] as List? ?? <dynamic>[];
      if (grades.isNotEmpty) {
        final totalPct = grades.fold<double>(0.0, (sum, g) {
          final row = g as Map<String, dynamic>;
          return sum + ((row['percentage'] as num?)?.toDouble() ?? 0.0);
        });
        overallPerf = totalPct / grades.length;
      }

      return StudentDashboardData(
        totalClasses: assignedClass != null ? 1 : 0,
        totalSubjects: assignedClassSubjects.length,
        attendancePercentage: attendancePct,
        pendingAssignments: pendingAssignments,
        totalAssignments: totalAssignments,
        overallPerformance: overallPerf,
      );
    } catch (e) {
      debugPrint('Dashboard Data Error: $e');
      return StudentDashboardData();
    }
  }

  // ─── Get Student's Classes and Subjects ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyClasses() async {
    try {
      final headers = await _getHeaders();
      final user = await getCurrentUser();
      if (user == null) return [];

      final cacheKey = _cacheKeyClasses(user.id);

      final classesRaw = await offlineFirstReadList(
        cacheKey: cacheKey,
        fetchFn: () async {
          final response = await http.get(
            Uri.parse('$baseUrl/api/academics/student-classes/?student=${user.id}&is_active=true'),
            headers: headers,
          );

          if (response.statusCode != 200) return <Map<String, dynamic>>[];

          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? data as List? ?? [];

          final classes = <Map<String, dynamic>>[];
          for (final entry in results) {
            final classEntry = entry as Map<String, dynamic>;
            final classIdRaw = classEntry['class_obj'];
            final classId = classIdRaw is int ? classIdRaw : int.tryParse(classIdRaw?.toString() ?? '');
            if (classId == null) continue;

            final classRes = await http.get(
              Uri.parse('$baseUrl/api/academics/classes/$classId/'),
              headers: headers,
            );

            if (classRes.statusCode != 200) continue;
            final classData = jsonDecode(classRes.body) as Map<String, dynamic>;

            final subjectsRes = await http.get(
              Uri.parse('$baseUrl/api/academics/class-subjects/?class_obj=$classId'),
              headers: headers,
            );

            List<Map<String, dynamic>> subjects = [];
            if (subjectsRes.statusCode == 200) {
              final subjectsData = jsonDecode(subjectsRes.body);
              final subjectResults = subjectsData['results'] as List? ?? subjectsData as List? ?? [];
              subjects = subjectResults
                  .whereType<Map>()
                  .map((s) => Map<String, dynamic>.from(s))
                  .map((s) => {
                        'id': s['subject'] is int ? s['subject'] : int.tryParse('${s['subject'] ?? ''}'),
                        'name': s['subject_name'] ?? '',
                        'code': s['subject_code'] ?? '',
                      })
                  .where((s) => s['id'] != null)
                  .toList();
            }

            classes.add({
              'id': classId,
              'name': classData['name'] ?? '',
              'level': classData['level_name'],
              'subjects': subjects,
              'subject_count': subjects.length,
            });
          }

          return classes;
        },
      );

      return classesRaw ?? <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('getMyClasses Error: $e');
      return [];
    }
  }

  // ─── Timetable ──────────────────────────────────────────────────

  Future<Map<String, List<TimetableEntry>>> getTimetableByDay() async {
    try {
      final headers = await _getHeaders();
      final user = await getCurrentUser();
      if (user == null) return {};

      // Get student's class
      final classResponse = await http.get(
        Uri.parse('$baseUrl/api/academics/student-classes/?student=${user.id}&is_active=true'),
        headers: headers,
      );

      if (classResponse.statusCode != 200) return {};

      final classData = jsonDecode(classResponse.body);
      final classResults = classData['results'] as List? ?? classData as List? ?? [];
      if (classResults.isEmpty) return {};

      final classIdRaw = classResults.first['class_obj'];
      if (classIdRaw == null) return {};
      final classId = classIdRaw is int ? classIdRaw.toString() : classIdRaw.toString();

      // Get timetable for this class
      final ttResponse = await http.get(
        Uri.parse('$baseUrl/api/academics/timetables/?class_obj=$classId'),
        headers: headers,
      );

      if (ttResponse.statusCode != 200) return {};

      final ttData = jsonDecode(ttResponse.body);
      final ttResults = ttData['results'] as List? ?? ttData as List? ?? [];

      final days = {'monday': <TimetableEntry>[], 'tuesday': <TimetableEntry>[], 'wednesday': <TimetableEntry>[], 'thursday': <TimetableEntry>[], 'friday': <TimetableEntry>[]};

      for (final entry in ttResults) {
        final timetableEntry = TimetableEntry.fromJson(entry as Map<String, dynamic>);
        final day = timetableEntry.day.toLowerCase();
        if (days.containsKey(day)) {
          days[day]!.add(timetableEntry);
        }
      }

      // Sort each day by start time
      for (final day in days.keys) {
        days[day]!.sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      return days;
    } catch (e) {
      debugPrint('Timetable Error: $e');
      return {};
    }
  }

  // ─── Results / Grades ───────────────────────────────────────────

  Future<List<StudentSubjectPerformance>> getResults() async {
    try {
      final headers = await _getHeaders();
      final user = await getCurrentUser();
      if (user == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/students/grades/?student=${user.id}'),
        headers: headers,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List? ?? [];

      // Group by subject and compute average
      final Map<String, List<double>> subjectScores = {};
      final Map<String, String> subjectGrades = {};

      for (final g in results) {
        final name = g['subject_name'] as String? ?? 'Unknown';
        final score = (g['score'] as num?)?.toDouble() ?? 0.0;
        final grade = g['grade'] as String? ?? '';
        
        subjectScores.putIfAbsent(name, () => []).add(score);
        if (grade.isNotEmpty) subjectGrades[name] = grade;
      }

      return subjectScores.entries.map((entry) {
        final scores = entry.value;
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        return StudentSubjectPerformance(
          subjectName: entry.key,
          score: avg,
          maxScore: 100,
          grade: subjectGrades[entry.key] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Results Error: $e');
      return [];
    }
}

  // ─── Assignments ────────────────────────────────────────────────

  List<dynamic> _extractAssignmentsFromPayload(dynamic raw) {
    if (raw is List) return raw;

    if (raw is Map<String, dynamic>) {
      const directListKeys = [
        'results',
        'data',
        'assignments',
        'items',
        'records',
        'student_assignments',
      ];

      for (final key in directListKeys) {
        final value = raw[key];
        if (value is List) return value;
      }

      const nestedMapKeys = [
        'dashboard',
        'student',
        'payload',
        'response',
        'result',
      ];

      for (final key in nestedMapKeys) {
        final nested = raw[key];
        if (nested is Map<String, dynamic>) {
          final nestedList = _extractAssignmentsFromPayload(nested);
          if (nestedList.isNotEmpty) return nestedList;
        }
      }
    }

    return const <dynamic>[];
  }

  Future<List<StudentAssignment>> _fetchAssignmentsFromEndpoint(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    if (response.statusCode != 200) return const <StudentAssignment>[];

    final raw = jsonDecode(response.body);
    final rows = _extractAssignmentsFromPayload(raw);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(StudentAssignment.fromJson)
        .toList();
  }

  Future<List<StudentAssignment>> getAssignments() async {
    try {
      final headers = await _getHeaders();

      final candidateEndpoints = <String>[
        '/api/assignments/student-assignments/',
        '/api/students/student-portal/assignments/',
        '/api/students/assignments/',
        '/api/academics/assignments/',
      ];

      List<StudentAssignment> assignments = const <StudentAssignment>[];
      for (final endpoint in candidateEndpoints) {
        assignments = await _fetchAssignmentsFromEndpoint(endpoint, headers);
        if (assignments.isNotEmpty) break;
      }

      final pending = assignments.where((a) => !a.isSubmitted).length;
      if (pending > 0) {
        await NotificationService.instance.showLocalNotification(
          title: 'Assignment Reminder',
          body: 'You have $pending pending assignment(s) to submit.',
          type: AppNotificationType.assignment,
          payload: {'type': 'assignment', 'pending_count': pending},
        );
      }

      return assignments;
    } catch (e) {
      debugPrint('Assignments Error: $e');
      return [];
    }
  }

  Future<StudentAssignment?> getAssignmentById(String assignmentId) async {
    try {
      final assignments = await getAssignments();
      for (final assignment in assignments) {
        if (assignment.id == assignmentId) return assignment;
      }
    } catch (e) {
      debugPrint('Assignment detail lookup error: $e');
    }
    return null;
  }

  // ─── Materials (Documents) ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMaterials() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/academics/documents/'),
        headers: headers,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> results = data is List
          ? data
          : (data is Map<String, dynamic> && data['results'] is List
              ? data['results'] as List
              : <dynamic>[]);

      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Materials Error: $e');
      return [];
    }
  }

  String? resolveMaterialUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '$baseUrl$trimmed';
    return '$baseUrl/$trimmed';
  }

  Future<bool> openMaterialInApp(String? rawUrl) async {
    final resolved = resolveMaterialUrl(rawUrl);
    if (resolved == null) return false;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.inAppWebView);
  }

  Future<bool> downloadMaterial(String? rawUrl) async {
    final resolved = resolveMaterialUrl(rawUrl);
    if (resolved == null) return false;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<StudentAiResponse> askStudentAi({
    required String prompt,
    String contextType = 'general',
    String? contextId,
    int numQuestions = 3,
    String questionType = 'short_answer',
    String difficulty = 'medium',
  }) async {
    try {
      final headers = await _getHeaders();

      final hasDocumentContext = contextId != null && contextId.trim().isNotEmpty;
      final endpoint = hasDocumentContext
          ? '$baseUrl/api/academics/documents/${contextId!.trim()}/generate_questions/'
          : '$baseUrl/api/academics/documents/generate_questions_from_topic/';

      final payload = <String, dynamic>{
        'num_questions': numQuestions,
        'question_type': questionType,
        'difficulty': difficulty,
      };

      if (hasDocumentContext) {
        payload['topic'] = prompt;
      } else {
        payload['topic'] = prompt;
        payload['subject'] = contextType;
        payload['context_id'] = contextId;
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return StudentAiResponse(
          success: false,
          message: '',
          error: 'Server error (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return StudentAiResponse(
          success: true,
          message: 'I could not generate a detailed response, please try rephrasing your question.',
        );
      }

      if (data['error'] != null) {
        return StudentAiResponse(
          success: false,
          message: '',
          error: data['error'].toString(),
        );
      }

      List<dynamic> questionItems = [];
      final rootQuestions = data['questions'];
      if (rootQuestions is List) {
        questionItems = rootQuestions;
      } else if (rootQuestions is Map<String, dynamic> && rootQuestions['questions'] is List) {
        questionItems = rootQuestions['questions'] as List<dynamic>;
      }

      if (questionItems.isEmpty) {
        return StudentAiResponse(
          success: true,
          message: 'I could not generate a detailed response, please try rephrasing your question.',
        );
      }

      final extractedQuestions = <String>[];
      final answerHints = <String>[];

      for (final item in questionItems) {
        if (item is! Map<String, dynamic>) continue;
        final q = item['question']?.toString().trim();
        if (q != null && q.isNotEmpty) {
          extractedQuestions.add(q);
        }
        final expl = item['explanation']?.toString().trim();
        if (expl != null && expl.isNotEmpty) {
          answerHints.add(expl);
        }
      }

      if (extractedQuestions.isEmpty && answerHints.isEmpty) {
        return StudentAiResponse(
          success: true,
          message: 'I generated results, but they came back empty. Please try a different topic.',
        );
      }

      final buffer = StringBuffer();
      if (extractedQuestions.isNotEmpty) {
        buffer.writeln('Here are some practice questions:');
        for (int i = 0; i < extractedQuestions.length; i++) {
          buffer.writeln('${i + 1}. ${extractedQuestions[i]}');
        }
      }
      if (answerHints.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln('Quick guidance:');
        buffer.writeln(answerHints.first);
      }

      return StudentAiResponse(
        success: true,
        message: buffer.toString().trim(),
        questions: extractedQuestions,
      );
    } catch (e) {
      debugPrint('Student AI Error: $e');
      return StudentAiResponse(
        success: false,
        message: '',
        error: 'Failed to connect to AI service',
      );
    }
  }

  // ─── Attendance History ─────────────────────────────────────────

  Future<Map<String, dynamic>> getAttendanceReport() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/student-portal/attendance_report/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('Attendance Report Error: $e');
      return {};
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAttendanceHistory() async {
    try {
      final headers = await _getHeaders();
      final user = await getCurrentUser();
      if (user == null) return {};

      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/?student_id=${user.id}'),
        headers: headers,
      );

      if (response.statusCode != 200) return {};

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List? ?? [];

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in results) {
        final record = r as Map<String, dynamic>;
        final date = (record['date'] as String? ?? '').split('T').first;
        // Extract month for grouping
        final month = date.length >= 7 ? date.substring(0, 7) : date;
        grouped.putIfAbsent(month, () => []).add(record);
      }

      return grouped;
    } catch (e) {
      debugPrint('Attendance History Error: $e');
      return {};
    }
  }

// ─── Announcements ──────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messaging/announcements/'),
        headers: headers,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List? ?? [];
      return results.map((a) => Announcement.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Announcements Error: $e');
      return [];
    }
  }

  // ─── Notices ───────────────────────────────────────────────

  Future<List<Notice>> getNotices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messaging/notices/'),
        headers: headers,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List? ?? [];
      return results.map((n) => Notice.fromJson(n as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Notices Error: $e');
      return [];
    }
  }

  // ─── Personal Notices ───────────────────────────────────────────

  Future<List<PersonalNotice>> getPersonalNotices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messaging/notices/my_personal_notices/'),
        headers: headers,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List? ?? [];
      return results.map((n) => PersonalNotice.fromJson(n as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Personal Notices Error: $e');
      return [];
    }
  }

  // ─── Fees ───────────────────────────────────────────────────────

  List<dynamic> _extractListFromPayload(dynamic raw) {
    if (raw is List) return raw;

    if (raw is Map<String, dynamic>) {
      const directListKeys = [
        'results',
        'data',
        'fees',
        'fee_records',
        'items',
        'records',
        'billing',
        'student_fees',
      ];

      for (final key in directListKeys) {
        final value = raw[key];
        if (value is List) return value;
      }

      const nestedMapKeys = [
        'dashboard',
        'student',
'payload',
        'response',
        'result',
      ];

      for (final key in nestedMapKeys) {
        final nested = raw[key];
        if (nested is Map<String, dynamic>) {
          final nestedList = _extractListFromPayload(nested);
          if (nestedList.isNotEmpty) return nestedList;
        }
      }

      if (raw.isNotEmpty && raw.values.every((v) => v is Map<String, dynamic>)) {
        return raw.values.toList();
      }
    }

    return const <dynamic>[];
  }

  Future<List<Fee>> _fetchFeesFromEndpoint(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    if (response.statusCode != 200) return const <Fee>[];

    final raw = jsonDecode(response.body);
    final rows = _extractListFromPayload(raw);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(Fee.fromJson)
        .where((fee) => fee.id.isNotEmpty || fee.title.trim().isNotEmpty)
        .toList();
  }

  Future<List<Fee>> getFees() async {
    try {
      final headers = await _getHeaders();

      final candidateEndpoints = <String>[
        '/api/students/student-billing/my_billing/',
        '/api/students/student-billing/',
        '/api/students/student-portal/dashboard/',
        '/api/students/student-portal/',
      ];

      List<Fee> fees = const <Fee>[];
      for (final endpoint in candidateEndpoints) {
        fees = await _fetchFeesFromEndpoint(endpoint, headers);
        if (fees.isNotEmpty) break;
      }

      final overdueCount = fees.where((f) => f.isOverdue).length;
      if (overdueCount > 0) {
        await NotificationService.instance.showLocalNotification(
          title: 'Fees Update',
          body: 'You have $overdueCount overdue fee item(s).',
          type: AppNotificationType.fees,
          payload: {'type': 'fees', 'overdue_count': overdueCount},
        );
      }

      return fees;
    } catch (e) {
      debugPrint('Fees Error: $e');
      return [];
    }
  }

  /// Get fee summary statistics
  Future<Map<String, dynamic>> getFeeSummary() async {
    final fees = await getFees();
    double totalAmount = 0;
    double totalPaid = 0;
    int overdueCount = 0;

    for (final fee in fees) {
      totalAmount += fee.totalAssigned;
      totalPaid += fee.paidAmount;
      if (fee.isOverdue) overdueCount++;
    }

    return {
      'total_amount': totalAmount,
      'total_paid': totalPaid,
      'balance': totalAmount - totalPaid,
      'overdue_count': overdueCount,
      'total_items': fees.length,
      'paid_items': fees.where((f) => f.isPaid).length,
    };
  }

  // ─── Profile ────────────────────────────────────────────────────

  String? resolveProfileImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '$baseUrl$trimmed';
    return '$baseUrl/$trimmed';
  }
}
