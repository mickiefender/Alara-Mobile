import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';

int _toInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double _toDouble(dynamic value, {double defaultValue = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

class SubjectScoreResult {
  final int subjectId;
  final String subjectName;
  final double totalScore;
  final double percentage;
  final String grade;
  final int? subjectPosition;
  final int subjectTotalStudents;

  SubjectScoreResult({
    required this.subjectId,
    required this.subjectName,
    required this.totalScore,
    required this.percentage,
    required this.grade,
    this.subjectPosition,
    required this.subjectTotalStudents,
  });

  factory SubjectScoreResult.fromJson(Map<String, dynamic> json) {
    return SubjectScoreResult(
      subjectId: _toInt(json['subject_id']),
      subjectName: json['subject_name']?.toString() ?? '',
      totalScore: _toDouble(json['total_score']),
      percentage: _toDouble(json['percentage']),
      grade: json['grade']?.toString() ?? 'F',
      subjectPosition: json['subject_position'] == null ? null : _toInt(json['subject_position']),
      subjectTotalStudents: _toInt(json['subject_total_students']),
    );
  }
}

class StudentTerminalReport {
  final int id;
  final int studentId;
  final String studentName;
  final int classId;
  final String? className;
  final int? sessionId;
  final String? sessionName;
  final double totalMarks;
  final double averageMarks;
  final int? position;
  final int totalStudents;
  final String grade;
  final int totalDays;
  final int daysPresent;
  final double attendancePercentage;
  final String promotionStatus;
  final String bestSubjectName;
  final double bestSubjectScore;
  final String formTeacherRemarks;
  final String principalRemarks;
  final String status;
  final List<SubjectScoreResult> subjectScores;

  StudentTerminalReport({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    this.className,
    this.sessionId,
    this.sessionName,
    required this.totalMarks,
    required this.averageMarks,
    this.position,
    required this.totalStudents,
    required this.grade,
    required this.totalDays,
    required this.daysPresent,
    required this.attendancePercentage,
    required this.promotionStatus,
    required this.bestSubjectName,
    required this.bestSubjectScore,
    required this.formTeacherRemarks,
    required this.principalRemarks,
    required this.status,
    required this.subjectScores,
  });

  String get positionText {
    if (position == null) return 'N/A';
    final suffix = _ordinalSuffix(position!);
    return '$position$suffix';
  }

  String get promotionText {
    switch (promotionStatus) {
      case 'promoted': return 'Promoted';
      case 'repeated': return 'Repeat';
      default: return 'Pending';
    }
  }

  bool get isPassing => promotionStatus == 'promoted';

  static String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  String get attendanceText {
    return '${attendancePercentage.toStringAsFixed(1)}% ($daysPresent/$totalDays days)';
  }

  factory StudentTerminalReport.fromJson(Map<String, dynamic> json) {
    return StudentTerminalReport(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      classId: json['class_id'] ?? 0,
      className: json['class_name']?.toString(),
      sessionId: json['session_id'] == null ? null : _toInt(json['session_id']),
      sessionName: json['session_name']?.toString(),
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 0,
      averageMarks: (json['average_marks'] as num?)?.toDouble() ?? 0,
      position: json['position'] == null ? null : _toInt(json['position']),
      totalStudents: json['total_students'] ?? 0,
      grade: json['grade'] ?? 'F',
      totalDays: json['total_days'] ?? 0,
      daysPresent: json['days_present'] ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0,
      promotionStatus: json['promotion_status'] ?? 'unknown',
      bestSubjectName: json['best_subject_name'] ?? '',
      bestSubjectScore: (json['best_subject_score'] as num?)?.toDouble() ?? 0,
      formTeacherRemarks: json['form_teacher_remarks'] ?? '',
      principalRemarks: json['principal_remarks'] ?? '',
      status: json['status'] ?? 'draft',
      subjectScores: (json['subject_scores'] as List? ?? [])
          .map((s) => SubjectScoreResult.fromJson(s))
          .toList(),
    );
  }
}

class GradingSystemEntry {
  final String gradeLetter;
  final double minPercentage;
  final double maxPercentage;
  final String remark;
  final bool promotionEligible;
  final bool isPassing;
  final int order;

  GradingSystemEntry({
    required this.gradeLetter,
    required this.minPercentage,
    required this.maxPercentage,
    required this.remark,
    required this.promotionEligible,
    required this.isPassing,
    required this.order,
  });

  factory GradingSystemEntry.fromJson(Map<String, dynamic> json) {
    return GradingSystemEntry(
      gradeLetter: json['grade_letter']?.toString() ?? '',
      minPercentage: (json['min_percentage'] as num?)?.toDouble() ?? 0,
      maxPercentage: (json['max_percentage'] as num?)?.toDouble() ?? 0,
      remark: json['remark']?.toString() ?? '',
      promotionEligible: json['promotion_eligible'] == true,
      isPassing: json['is_passing'] == true,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class GradingSystemInfo {
  final int id;
  final String name;
  final bool isDefault;
  final List<GradingSystemEntry> entries;

  GradingSystemInfo({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.entries,
  });

  factory GradingSystemInfo.fromJson(Map<String, dynamic> json) {
    return GradingSystemInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      isDefault: json['is_default'] == true,
      entries: (json['entries'] as List? ?? [])
          .map((e) => GradingSystemEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AssessmentTypeInfo {
  final int id;
  final String title;
  final String category;
  final int? subjectId;
  final String? subjectName;
  final int? term;
  final double totalMarks;
  final double weightPercentage;
  final String? assessmentDate;

  AssessmentTypeInfo({
    required this.id,
    required this.title,
    required this.category,
    this.subjectId,
    this.subjectName,
    this.term,
    required this.totalMarks,
    required this.weightPercentage,
    this.assessmentDate,
  });

  factory AssessmentTypeInfo.fromJson(Map<String, dynamic> json) {
    return AssessmentTypeInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subjectId: (json['subject_id'] as num?)?.toInt(),
      subjectName: json['subject_name']?.toString(),
      term: (json['term'] as num?)?.toInt(),
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 0,
      weightPercentage: (json['weight_percentage'] as num?)?.toDouble() ?? 0,
      assessmentDate: json['assessment_date']?.toString(),
    );
  }
}

class ClassReportsSummary {
  final int totalStudents;
  final double averageScore;
  final String? bestStudentName;
  final double bestStudentScore;
  final String? bestSubjectName;
  final double bestSubjectScore;
  final int studentsPromoted;
  final int studentsRepeated;

  ClassReportsSummary({
    required this.totalStudents,
    required this.averageScore,
    this.bestStudentName,
    required this.bestStudentScore,
    this.bestSubjectName,
    required this.bestSubjectScore,
    required this.studentsPromoted,
    required this.studentsRepeated,
  });

  factory ClassReportsSummary.fromJson(Map<String, dynamic> json) {
    return ClassReportsSummary(
      totalStudents: json['total_students'] ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
      bestStudentName: json['best_student_name']?.toString(),
      bestStudentScore: (json['best_student_score'] as num?)?.toDouble() ?? 0,
      bestSubjectName: json['best_subject_name']?.toString(),
      bestSubjectScore: (json['best_subject_score'] as num?)?.toDouble() ?? 0,
      studentsPromoted: json['students_promoted'] ?? 0,
      studentsRepeated: json['students_repeated'] ?? 0,
    );
  }
}

class TerminalReportsData {
  final List<StudentTerminalReport> reports;
  final ClassReportsSummary? summary;
  final GradingSystemInfo? gradingSystem;
  final List<AssessmentTypeInfo> continuousAssessments;
  final List<AssessmentTypeInfo> examinations;

  TerminalReportsData({
    required this.reports,
    this.summary,
    this.gradingSystem,
    required this.continuousAssessments,
    required this.examinations,
  });

  factory TerminalReportsData.fromJson(Map<String, dynamic> json) {
    final assessments = _asMap(json['assessments']);
    final results = _asMapList(json['results']);
    final summaryMap = _asMap(json['summary']);
    final gradingSystemMap = _asMap(json['grading_system']);

    return TerminalReportsData(
      reports: results
          .map((r) => StudentTerminalReport.fromJson(r))
          .toList(),
      summary: summaryMap.isNotEmpty ? ClassReportsSummary.fromJson(summaryMap) : null,
      gradingSystem: gradingSystemMap.isNotEmpty
          ? GradingSystemInfo.fromJson(gradingSystemMap)
          : null,
      continuousAssessments: _asMapList(assessments['continuous_assessments'])
          .map((a) => AssessmentTypeInfo.fromJson(a))
          .toList(),
      examinations: _asMapList(assessments['examinations'])
          .map((a) => AssessmentTypeInfo.fromJson(a))
          .toList(),
    );
  }
}

class TerminalReportService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Compute terminal reports for ALL students in a class
  Future<Map<String, dynamic>> computeClassReports({
    required int classId,
    required int sessionId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/terminal-reports/compute_class_reports/'),
        headers: headers,
        body: jsonEncode({
          'class_id': classId,
          'session_id': sessionId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('Compute Reports Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to compute reports');
    } catch (e) {
      debugPrint('Compute Reports Service Error: $e');
      rethrow;
    }
  }

  /// Get all terminal reports for a class/session
  Future<TerminalReportsData> getClassReports({
    required int classId,
    int? sessionId,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'class_id': classId.toString(),
      };
      if (sessionId != null) queryParams['session_id'] = sessionId.toString();

      final uri = Uri.parse('$baseUrl/api/academics/terminal-reports/class_reports/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return TerminalReportsData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('Class Reports Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load reports');
    } catch (e) {
      debugPrint('Class Reports Service Error: $e');
      rethrow;
    }
  }

  /// Generate a single terminal report
  Future<Map<String, dynamic>> generateReport({
    required int studentId,
    required int classId,
    required int sessionId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/academics/terminal-reports/generate_report/'),
        headers: headers,
        body: jsonEncode({
          'student_id': studentId,
          'class_id': classId,
          'session_id': sessionId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      debugPrint('Generate Report Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to generate report');
    } catch (e) {
      debugPrint('Generate Report Service Error: $e');
      rethrow;
    }
  }
}
