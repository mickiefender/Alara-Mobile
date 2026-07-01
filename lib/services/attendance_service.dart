import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';
import 'package:alara/core/services/notification_service.dart';

class StudentAttendanceRecord {
  final String id;
  final String name;
  final String? profileImage;
  final String? rollNumber;
  final String? studentId;
  String status;

  StudentAttendanceRecord({
    required this.id,
    required this.name,
    this.profileImage,
    this.rollNumber,
    this.studentId,
    this.status = 'present',
  });

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceRecord(
      id: json['id'].toString(),
      name: _extractName(json),
      profileImage: json['profile_image']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      studentId: json['student_id']?.toString(),
      status: 'present',
    );
  }

  static String _extractName(Map<String, dynamic> json) {
    if ((json['name']?.toString().trim().isNotEmpty ?? false)) {
      return json['name'].toString();
    }
    final first = (json['first_name'] ?? '').toString().trim();
    final last = (json['last_name'] ?? '').toString().trim();
    return '$first $last'.trim().isNotEmpty ? '$first $last' : 'Unknown';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profile_image': profileImage,
    'roll_number': rollNumber,
    'student_id': studentId,
    'status': status,
  };
}

class AttendanceService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all classes assigned to the teacher — with offline cache fallback
  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    final cacheKey = 'attendance:teacher_classes';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/students/my_classes/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? [];
          return results.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Classes API Error: ${response.statusCode} - ${response.body}');
          return null;
        }
      },
    );

    return result ?? [];
  }

  /// Fetch subjects assigned to the teacher for a specific class
  Future<List<Map<String, dynamic>>> getTeacherSubjectsForClass(String classId) async {
    final cacheKey = 'attendance:subjects:$classId';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/classes/my_class_subjects/?class_obj=$classId'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? [];
          return results.map((r) => {
            'id': r['subject_id'].toString(),
            'name': r['subject_name']?.toString() ?? 'Unknown',
            'code': r['subject_code']?.toString(),
          }).toList();
        } else {
          debugPrint('Subjects API Error: ${response.statusCode} - ${response.body}');
          return null;
        }
      },
    );

    return result ?? [];
  }

  /// Fetch students for a given class/section — with offline cache fallback
  Future<List<StudentAttendanceRecord>> getStudents(String classId, {String? section}) async {
    final cacheKey = 'attendance:students:$classId${section != null ? ':$section' : ''}';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        String url = '$baseUrl/api/users/students/?class_id=$classId';
        if (section != null && section.isNotEmpty) {
          url += '&section=$section';
        }

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? data as List? ?? [];
          return results.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Students API Error: ${response.statusCode} - ${response.body}');
          return null;
        }
      },
    );

    if (result == null) return [];
    return result.map((s) => StudentAttendanceRecord.fromJson(s)).toList();
  }

  /// Submit attendance records — with offline write-queuing
  Future<bool> submitAttendance({
    required String classId,
    required DateTime date,
    required String subjectId,
    required List<Map<String, String>> records,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final attendances = records.map((r) => {
      'class_obj': classId,
      'subject': subjectId,
      'student': r['student_id']!,
      'date': dateStr,
      'status': r['status']!,
    }).toList();

    final payload = {'attendances': attendances};
    final entityId = 'attendance:$classId:$dateStr:$subjectId';

    return offlineFirstWrite(
      entityType: 'attendance',
      entityId: entityId,
      endpoint: '/api/attendance/bulk_mark/',
      method: 'POST',
      payload: payload,
      cacheKey: 'attendance:existing:$classId:$dateStr',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/api/attendance/bulk_mark/'),
          headers: headers,
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('Submit Attendance Success: ${response.body}');
          await NotificationService.instance.showLocalNotification(
            title: 'Attendance Marked',
            body: 'Attendance has been submitted for ${records.length} student(s).',
            type: AppNotificationType.attendance,
            payload: {
              'type': 'attendance',
              'class_id': classId,
              'subject_id': subjectId,
              'date': dateStr,
            },
          );
          return true;
        } else {
          debugPrint('Submit Attendance Error: ${response.statusCode} - ${response.body}');
          return false;
        }
      },
    );
  }

  /// Fetch existing attendance for a class/date — with offline cache fallback
  Future<Map<String, String>> getExistingAttendance(String classId, DateTime date, {String? subjectId}) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final cacheKey = 'attendance:existing:$classId:$dateStr${subjectId != null ? ':$subjectId' : ''}';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        String url = '$baseUrl/api/attendance/?class_id=$classId&date=$dateStr';
        if (subjectId != null) {
          url += '&subject=$subjectId';
        }

        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? data as List? ?? [];
          final map = <String, String>{};
          for (final r in results) {
            map[r['student'].toString()] = r['status'] as String;
          }
          return map;
        }
        return null;
      },
    );

    if (result == null) return <String, String>{};
    return result.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}
