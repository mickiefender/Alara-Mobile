import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _asDynamicList(dynamic value) {
  if (value is List) return value;
  return const [];
}

class TeacherDashboardData {
  final List<AssignedClass> assignedClasses;
  final List<SubjectAssignment> subjectAssignments;
  final DashboardSummary summary;
  final AttendanceOverview attendanceOverview;
  final GenderDistribution genderDistribution;

  TeacherDashboardData({
    required this.assignedClasses,
    required this.subjectAssignments,
    required this.summary,
    required this.attendanceOverview,
    required this.genderDistribution,
  });

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) {
    return TeacherDashboardData(
      assignedClasses: _asDynamicList(json['assigned_classes'])
          .map((item) => AssignedClass.fromJson(_asStringDynamicMap(item)))
          .toList(),
      subjectAssignments: _asDynamicList(json['subject_assignments'])
          .map((item) => SubjectAssignment.fromJson(_asStringDynamicMap(item)))
          .toList(),
      summary: DashboardSummary.fromJson(_asStringDynamicMap(json['summary'])),
      attendanceOverview: AttendanceOverview.fromJson(
        _asStringDynamicMap(json['attendance_overview']),
      ),
      genderDistribution: GenderDistribution.fromJson(
        _asStringDynamicMap(json['gender_distribution']),
      ),
    );
  }

  int get myClasses => summary.totalClasses;
  int get myStudents => summary.totalStudents;
  int get activeAssignments => summary.totalSubjectAssignments;
  int get pendingReviews => 0;
}

class AttendanceOverview {
  final int present;
  final int late;
  final int absent;

  AttendanceOverview({
    required this.present,
    required this.late,
    required this.absent,
  });

  factory AttendanceOverview.fromJson(Map<String, dynamic> json) {
    return AttendanceOverview(
      present: json['present'] ?? 0,
      late: json['late'] ?? 0,
      absent: json['absent'] ?? 0,
    );
  }

  int get total => present + late + absent;
}

class GenderDistribution {
  final int male;
  final int female;

  GenderDistribution({
    required this.male,
    required this.female,
  });

  factory GenderDistribution.fromJson(Map<String, dynamic> json) {
    return GenderDistribution(
      male: json['male'] ?? 0,
      female: json['female'] ?? 0,
    );
  }
}

class DashboardSummary {
  final int totalClasses;
  final int totalSubjectAssignments;
  final int totalStudents;

  DashboardSummary({
    required this.totalClasses,
    required this.totalSubjectAssignments,
    required this.totalStudents,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalClasses: json['total_classes'] ?? 0,
      totalSubjectAssignments: json['total_subject_assignments'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
    );
  }
}

class AssignedClass {
  final int classId;
  final String className;
  final String? levelName;
  final bool isFormTutor;
  final int studentCount;

  AssignedClass({
    required this.classId,
    required this.className,
    required this.levelName,
    required this.isFormTutor,
    required this.studentCount,
  });

  factory AssignedClass.fromJson(Map<String, dynamic> json) {
    return AssignedClass(
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? 'Class',
      levelName: json['level_name'],
      isFormTutor: json['is_form_tutor'] ?? false,
      studentCount: json['student_count'] ?? 0,
    );
  }
}

class SubjectAssignment {
  final int classId;
  final String className;
  final List<SubjectInfo> subjects;

  SubjectAssignment({
    required this.classId,
    required this.className,
    required this.subjects,
  });

  factory SubjectAssignment.fromJson(Map<String, dynamic> json) {
    return SubjectAssignment(
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? '',
      subjects: _asDynamicList(json['subjects'])
          .map((item) => SubjectInfo.fromJson(_asStringDynamicMap(item)))
          .toList(),
    );
  }
}

class ClassInfo {
  final int id;
  final String name;
  final String? classCode;
  final String? level;
  final int studentCount;
  final bool isFormTutor;
  final List<SubjectInfo> subjectsTaught;

  ClassInfo({
    required this.id,
    required this.name,
    this.classCode,
    this.level,
    required this.studentCount,
    required this.isFormTutor,
    required this.subjectsTaught,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      id: json['id'],
      name: json['name'],
      classCode: json['class_code'],
      level: json['level'],
      studentCount: json['student_count'] ?? 0,
      isFormTutor: json['is_form_tutor'] ?? false,
      subjectsTaught: _asDynamicList(json['subjects_taught'])
          .map((s) => SubjectInfo.fromJson(_asStringDynamicMap(s)))
          .toList(),
    );
  }
}

class SubjectInfo {
  final int id;
  final String name;
  final String? code;

  SubjectInfo({required this.id, required this.name, this.code});

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    return SubjectInfo(
      id: json['id'],
      name: json['name'],
      code: json['code'],
    );
  }
}

class TeacherDashboardService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  String? _resolveProfileImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '$baseUrl$trimmed';
    return '$baseUrl/$trimmed';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<TeacherDashboardData> getDashboardData() async {
    const cacheKey = 'teacher:dashboard';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/classes/teacher-dashboard/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          debugPrint('Dashboard API Error: ${response.statusCode} - ${response.body}');
          throw Exception('Failed to load dashboard data');
        }
      },
    );

    if (result == null) throw Exception('No dashboard data available');
    return TeacherDashboardData.fromJson(result);
  }

  Future<List<ClassInfo>> getMyClasses() async {
    const cacheKey = 'teacher:my_classes';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/students/my_classes/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = _asStringDynamicMap(jsonDecode(response.body));
          final results = _asDynamicList(data['results']);
          return <String, dynamic>{'results': results.map((c) => _asStringDynamicMap(c)).toList()};
        } else {
          debugPrint('Classes API Error: ${response.statusCode} - ${response.body}');
          return null;
        }
      },
    );

    if (result == null) return [];
    final results = _asDynamicList(result['results']);
    return results
        .map((c) => ClassInfo.fromJson(_asStringDynamicMap(c)))
        .toList();
  }

  Future<String?> getProfilePictureUrl() async {
    try {
      final headers = await _getHeaders();
      final user = await _authService.getCurrentUser();
      if (user == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = _asStringDynamicMap(jsonDecode(response.body));
        final rawUrl = (data['profile_picture'] ?? data['profile_image']) as String?;
        return _resolveProfileImageUrl(rawUrl);
      }
      return null;
    } catch (e) {
      debugPrint('Profile Picture Error: $e');
      return null;
    }
  }
}
