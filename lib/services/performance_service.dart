import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';

class StudentPerformance {
  final int studentId;
  final String studentName;
  final String? studentIdNumber;
  final String? profilePicture;
  final int classId;
  final String? className;
  final AttendanceStats attendance;
  final ExamPerformanceStats examPerformance;
  final List<SubjectPerformance> subjectPerformances;
  final double performanceScore;
  final String grade;
  final int totalClassStudents;

  StudentPerformance({
    required this.studentId,
    required this.studentName,
    this.studentIdNumber,
    this.profilePicture,
    required this.classId,
    this.className,
    required this.attendance,
    required this.examPerformance,
    required this.subjectPerformances,
    required this.performanceScore,
    required this.grade,
    required this.totalClassStudents,
  });

  factory StudentPerformance.fromJson(Map<String, dynamic> json) {
    return StudentPerformance(
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? 'Unknown',
      studentIdNumber: json['student_id_number']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      classId: json['class_id'] ?? 0,
      className: json['class_name']?.toString(),
      attendance: AttendanceStats.fromJson(json['attendance'] ?? {}),
      examPerformance: ExamPerformanceStats.fromJson(json['exam_performance'] ?? {}),
      subjectPerformances: (json['subject_performances'] as List? ?? [])
          .map((s) => SubjectPerformance.fromJson(s))
          .toList(),
      performanceScore: (json['performance_score'] ?? 0).toDouble(),
      grade: json['grade'] ?? 'N/A',
      totalClassStudents: json['total_class_students'] ?? 0,
    );
  }
}

class AttendanceStats {
  final int totalDays;
  final int present;
  final int absent;
  final int late;
  final double percentage;

  AttendanceStats({
    required this.totalDays,
    required this.present,
    required this.absent,
    required this.late,
    required this.percentage,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalDays: json['total_days'] ?? 0,
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      late: json['late'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class ExamPerformanceStats {
  final int totalExams;
  final double averageScore;
  final double highestScore;

  ExamPerformanceStats({
    required this.totalExams,
    required this.averageScore,
    required this.highestScore,
  });

  factory ExamPerformanceStats.fromJson(Map<String, dynamic> json) {
    return ExamPerformanceStats(
      totalExams: json['total_exams'] ?? 0,
      averageScore: (json['average_score'] ?? 0).toDouble(),
      highestScore: (json['highest_score'] ?? 0).toDouble(),
    );
  }
}

class SubjectPerformance {
  final String subjectName;
  final double averageScore;
  final double bestScore;
  final double latestScore;

  SubjectPerformance({
    required this.subjectName,
    required this.averageScore,
    required this.bestScore,
    required this.latestScore,
  });

  factory SubjectPerformance.fromJson(Map<String, dynamic> json) {
    return SubjectPerformance(
      subjectName: json['subject_name'] ?? 'Unknown',
      averageScore: (json['average_score'] ?? 0).toDouble(),
      bestScore: (json['best_score'] ?? 0).toDouble(),
      latestScore: (json['latest_score'] ?? 0).toDouble(),
    );
  }
}

class ClassPerformanceAnalytics {
  final int classId;
  final String? className;
  final int totalStudents;
  final double overallAttendancePercentage;
  final int totalAttendanceRecords;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double averageExamScore;
  final Map<String, int> gradeDistribution;
  final int maleStudents;
  final int femaleStudents;

  ClassPerformanceAnalytics({
    required this.classId,
    this.className,
    required this.totalStudents,
    required this.overallAttendancePercentage,
    required this.totalAttendanceRecords,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.averageExamScore,
    required this.gradeDistribution,
    required this.maleStudents,
    required this.femaleStudents,
  });

  factory ClassPerformanceAnalytics.fromJson(Map<String, dynamic> json) {
    final gradeDistRaw = json['grade_distribution'] as Map<String, dynamic>? ?? {};
    final gradeDistribution = gradeDistRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    return ClassPerformanceAnalytics(
      classId: json['class_id'] ?? 0,
      className: json['class_name']?.toString(),
      totalStudents: json['total_students'] ?? 0,
      overallAttendancePercentage: (json['overall_attendance_percentage'] ?? 0).toDouble(),
      totalAttendanceRecords: json['total_attendance_records'] ?? 0,
      presentCount: json['present_count'] ?? 0,
      absentCount: json['absent_count'] ?? 0,
      lateCount: json['late_count'] ?? 0,
      averageExamScore: (json['average_exam_score'] ?? 0).toDouble(),
      gradeDistribution: gradeDistribution,
      maleStudents: json['male_students'] ?? 0,
      femaleStudents: json['female_students'] ?? 0,
    );
  }
}

class TeacherPerformanceData {
  final List<ClassPerformanceAnalytics> classes;
  final List<StudentPerformance> students;
  final OverallStats? overallStats;

  TeacherPerformanceData({
    required this.classes,
    required this.students,
    this.overallStats,
  });

  factory TeacherPerformanceData.fromJson(Map<String, dynamic> json) {
    final rawClasses = (json['classes'] as List?) ?? (json['results'] as List?) ?? [];
    final parsedClasses = rawClasses
        .map((c) => _parseClassPerformance(c))
        .toList();

    final parsedStudents = (json['students'] as List? ?? [])
        .map((s) => StudentPerformance.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    OverallStats? parsedOverallStats;
    if (json['overall_stats'] != null) {
      parsedOverallStats = OverallStats.fromJson(Map<String, dynamic>.from(json['overall_stats']));
    } else if (parsedClasses.isNotEmpty) {
      final totalStudents = parsedClasses.fold<int>(0, (sum, c) => sum + c.totalStudents);
      final avgScore = parsedClasses.fold<double>(0, (sum, c) => sum + c.averageExamScore) / parsedClasses.length;
      final avgAttendance = parsedClasses.fold<double>(0, (sum, c) => sum + c.overallAttendancePercentage) / parsedClasses.length;
      final topClass = parsedClasses.toList()
        ..sort((a, b) => b.averageExamScore.compareTo(a.averageExamScore));

      parsedOverallStats = OverallStats(
        totalStudents: totalStudents,
        totalClasses: parsedClasses.length,
        averagePerformanceScore: avgScore,
        averageAttendancePercentage: avgAttendance,
        averageExamScore: avgScore,
        topPerformer: topClass.isNotEmpty ? topClass.first.className : null,
        studentsAtRisk: 0,
      );
    }

    return TeacherPerformanceData(
      classes: parsedClasses,
      students: parsedStudents,
      overallStats: parsedOverallStats,
    );
  }

  static ClassPerformanceAnalytics _parseClassPerformance(dynamic raw) {
    final c = Map<String, dynamic>.from(raw as Map);
    return ClassPerformanceAnalytics.fromJson({
      'class_id': c['class_id'] ?? c['classId'] ?? 0,
      'class_name': c['class_name'] ?? c['className'] ?? 'Class',
      'total_students': c['total_students'] ?? c['studentCount'] ?? c['student_count'] ?? 0,
      'overall_attendance_percentage': c['overall_attendance_percentage'] ?? c['attendancePercentage'] ?? 0,
      'total_attendance_records': c['total_attendance_records'] ?? 0,
      'present_count': c['present_count'] ?? 0,
      'absent_count': c['absent_count'] ?? 0,
      'late_count': c['late_count'] ?? 0,
      'average_exam_score': c['average_exam_score'] ?? c['averageScore'] ?? 0,
      'grade_distribution': c['grade_distribution'] ?? <String, int>{},
      'male_students': c['male_students'] ?? 0,
      'female_students': c['female_students'] ?? 0,
    });
  }
}

class OverallStats {
  final int totalStudents;
  final int totalClasses;
  final double averagePerformanceScore;
  final double averageAttendancePercentage;
  final double averageExamScore;
  final String? topPerformer;
  final int studentsAtRisk;

  OverallStats({
    required this.totalStudents,
    required this.totalClasses,
    required this.averagePerformanceScore,
    required this.averageAttendancePercentage,
    required this.averageExamScore,
    this.topPerformer,
    required this.studentsAtRisk,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    return OverallStats(
      totalStudents: json['total_students'] ?? 0,
      totalClasses: json['total_classes'] ?? 0,
      averagePerformanceScore: (json['average_performance_score'] ?? 0).toDouble(),
      averageAttendancePercentage: (json['average_attendance_percentage'] ?? 0).toDouble(),
      averageExamScore: (json['average_exam_score'] ?? 0).toDouble(),
      topPerformer: json['top_performer']?.toString(),
      studentsAtRisk: json['students_at_risk'] ?? 0,
    );
  }
}

class PerformanceService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<TeacherPerformanceData> getTeacherPerformance() async {
    const cacheKey = 'performance:teacher';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/classes/performance/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          debugPrint('Performance API Error: ${response.statusCode} - ${response.body}');
          throw Exception('Failed to load performance data');
        }
      },
    );

    if (result == null) throw Exception('No performance data available');
    return TeacherPerformanceData.fromJson(result);
  }

  Future<StudentPerformance> getStudentPerformanceDetail(int studentId, int classId) async {
    final cacheKey = 'performance:student:$studentId:class:$classId';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/classes/student-performance-detail/?student_id=$studentId&class_id=$classId'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          debugPrint('Student Detail API Error: ${response.statusCode} - ${response.body}');
          throw Exception('Failed to load student detail');
        }
      },
    );

    if (result == null) throw Exception('No student performance data');
    return StudentPerformance.fromJson(result);
  }

  Future<Map<String, dynamic>> getMyClasses() async {
    const cacheKey = 'performance:my_classes';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/students/my_classes/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data as Map<String, dynamic>;
        }
        return null;
      },
    );

    return result ?? {};
  }
}
