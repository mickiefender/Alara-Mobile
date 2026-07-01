import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/models/timetable.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';

class TimetableService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all classes assigned to the teacher (reuses same endpoint as attendance)
  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    final cacheKey = 'timetable:teacher_classes';

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

  /// Fetch timetable entries filtered by class and/or day
  Future<List<TimetableEntry>> getTimetable({
    int? classObjId,
    String? day,
  }) async {
    final normalizedDay = day?.toLowerCase();
    final classPart = classObjId != null ? 'class_$classObjId' : 'all';
    final dayPart = (normalizedDay != null && normalizedDay.isNotEmpty) ? normalizedDay : 'all';
    final cacheKey = 'timetable:entries:$classPart:$dayPart';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final queryParams = <String, String>{};
        if (classObjId != null) queryParams['class_obj'] = classObjId.toString();
        if (normalizedDay != null && normalizedDay.isNotEmpty) queryParams['day'] = normalizedDay;

        final uri = Uri.parse('$baseUrl/api/academics/timetables/')
            .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

        final response = await http.get(
          uri,
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? data as List? ?? [];
          return results.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Timetable API Error: ${response.statusCode} - ${response.body}');
          return null;
        }
      },
    );

    if (result == null) return [];
    return result.map((r) => TimetableEntry.fromJson(r)).toList();
  }

  /// Fetch timetable entries for all classes the teacher is assigned to,
  /// grouped by day. Since classes are already filtered to the teacher's own
  /// classes (via my_classes/), all timetable entries for those classes are
  /// shown — no per-entry teacher-ID filter needed.
  Future<Map<String, List<TimetableEntry>>> getTeacherTimetableByDay() async {
    final classes = await getTeacherClasses();
    if (classes.isEmpty) return {};

    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    final result = <String, List<TimetableEntry>>{};

    for (final day in days) {
      result[day] = [];
    }

    // Fetch timetable for each class
    for (final cls in classes) {
      final classId = cls['id'];
      if (classId == null) continue;

      final int classObjId;
      if (classId is int) {
        classObjId = classId;
      } else {
        classObjId = int.tryParse(classId.toString()) ?? 0;
      }
      if (classObjId == 0) continue;

      final entries = await getTimetable(classObjId: classObjId);
      for (final entry in entries) {
        final day = entry.day.toLowerCase();
        if (!result.containsKey(day)) continue;

        // Inject the class name from the API response if available, else from teacher's class list
        if (entry.className == null && cls['name'] != null) {
          result[day]!.add(TimetableEntry(
            id: entry.id,
            classObjId: entry.classObjId,
            subjectId: entry.subjectId,
            teacherId: entry.teacherId,
            day: entry.day,
            startTime: entry.startTime,
            endTime: entry.endTime,
            venue: entry.venue,
            subjectName: entry.subjectName,
            className: cls['name'].toString(),
            teacherName: entry.teacherName,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
          ));
        } else {
          result[day]!.add(entry);
        }
      }
    }

    // Sort entries within each day by start time
    for (final day in result.keys) {
      result[day]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return result;
  }
}
