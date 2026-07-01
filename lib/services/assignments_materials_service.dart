import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';
import 'package:alara/core/services/notification_service.dart';

// =============================================================================
// EXTENDED MODELS
// =============================================================================

class AssignmentListItem {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String subjectName;
  final String className;
  final String teacherName;
  final DateTime dueDate;
  final String? fileUrl;
  final int submissionCount;
  final int gradedCount;
  final DateTime createdAt;

  AssignmentListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.subjectName,
    required this.className,
    required this.teacherName,
    required this.dueDate,
    this.fileUrl,
    this.submissionCount = 0,
    this.gradedCount = 0,
    required this.createdAt,
  });

  bool get isOverdue => DateTime.now().isAfter(dueDate);
  Duration get timeRemaining => dueDate.difference(DateTime.now());
  bool get hasSubmissions => submissionCount > 0;

  factory AssignmentListItem.fromJson(Map<String, dynamic> json) {
    return AssignmentListItem(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Untitled Assignment',
      description: json['description'] as String? ?? '',
      subject: json['subject'].toString(),
      subjectName: json['subject_name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      fileUrl: json['file_url'] as String?,
      submissionCount: json['submission_count'] ?? 0,
      gradedCount: json['graded_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// A class/subject pair used in pickers
class ClassSubjectPair {
  final int classId;
  final String className;
  final int subjectId;
  final String subjectName;

  ClassSubjectPair({
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
  });

  factory ClassSubjectPair.fromJson(Map<String, dynamic> json) {
    return ClassSubjectPair(
      classId: json['class_id'] is int ? json['class_id'] : int.parse(json['class_id'].toString()),
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] is int ? json['subject_id'] : int.parse(json['subject_id'].toString()),
      subjectName: json['subject_name'] as String? ?? '',
    );
  }
}

class MaterialListItem {
  final int id;
  final String title;
  final String? description;
  final String? subjectName;
  final String? className;
  final String? uploadedByName;
  final String? folderName;
  final String? fileUrl;
  final String documentType;
  final String? fileSize;
  final bool isShared;
  final DateTime createdAt;
  bool isSelected;

  MaterialListItem({
    required this.id,
    required this.title,
    this.description,
    this.subjectName,
    this.className,
    this.uploadedByName,
    this.folderName,
    this.fileUrl,
    this.documentType = 'other',
    this.fileSize,
    this.isShared = false,
    required this.createdAt,
    this.isSelected = false,
  });

  String get fileExtension {
    if (fileUrl == null || !fileUrl!.contains('.')) return '?';
    return fileUrl!.split('.').last.split('?').first.toUpperCase();
  }

  IconType get iconType {
    final ext = fileExtension.toLowerCase();
    if (ext == 'pdf') return IconType.pdf;
    if (['doc', 'docx'].contains(ext)) return IconType.doc;
    if (['xls', 'xlsx'].contains(ext)) return IconType.sheet;
    if (['ppt', 'pptx'].contains(ext)) return IconType.presentation;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return IconType.image;
    if (['zip', 'rar', '7z'].contains(ext)) return IconType.archive;
    if (ext == 'txt') return IconType.text;
    return IconType.generic;
  }

  factory MaterialListItem.fromJson(Map<String, dynamic> json) {
    return MaterialListItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      subjectName: json['subject_name'] as String?,
      className: json['class_name'] as String?,
      uploadedByName: json['uploaded_by_name'] as String?,
      folderName: json['folder_name'] as String?,
      fileUrl: json['file_url'] as String?,
      documentType: json['document_type'] as String? ?? 'other',
      fileSize: json['file_size'] as String?,
      isShared: json['is_shared'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

enum IconType { pdf, doc, sheet, presentation, image, archive, text, generic }

// =============================================================================
// STATS MODELS
// =============================================================================

class AssignmentsStats {
  final int total;
  final int active;
  final int overdue;
  final int pendingGrading;
  final int submitted;

  AssignmentsStats({
    this.total = 0,
    this.active = 0,
    this.overdue = 0,
    this.pendingGrading = 0,
    this.submitted = 0,
  });

  factory AssignmentsStats.fromJson(Map<String, dynamic> json) {
    return AssignmentsStats(
      total: json['total'] ?? 0,
      active: json['active'] ?? 0,
      overdue: json['overdue'] ?? 0,
      pendingGrading: json['pending_grading'] ?? 0,
      submitted: json['submitted'] ?? 0,
    );
  }
}

class MaterialsStats {
  final int total;
  final int recentUploads;

  MaterialsStats({this.total = 0, this.recentUploads = 0});

  factory MaterialsStats.fromJson(Map<String, dynamic> json) {
    return MaterialsStats(
      total: json['total'] ?? 0,
      recentUploads: json['recent_uploads'] ?? 0,
    );
  }
}

// =============================================================================
// SERVICE
// =============================================================================

class AssignmentsMaterialsService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }


  // ---------------------------------------------------------------------------
  // ASSIGNMENTS
  // ---------------------------------------------------------------------------

  Future<List<AssignmentListItem>> getAssignments() async {
    const cacheKey = 'assignments:list';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/assignments/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> results = data is List<dynamic>
              ? data
              : (data is Map<String, dynamic> && data['results'] is List<dynamic>
                  ? data['results'] as List<dynamic>
                  : <dynamic>[]);
          return results.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Assignments API Error: ${response.statusCode}');
          return null;
        }
      },
    );

    if (result == null) return <AssignmentListItem>[];
    return result.map(AssignmentListItem.fromJson).toList().cast<AssignmentListItem>();
  }

  Future<AssignmentsStats> getAssignmentsStats() async {
    const cacheKey = 'assignments:stats';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/assignments/stats/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        return null;
      },
    );

    if (result == null) return AssignmentsStats();
    return AssignmentsStats.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // MATERIALS (Documents)
  // ---------------------------------------------------------------------------

  Future<List<MaterialListItem>> getMaterials() async {
    const cacheKey = 'materials:list';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/documents/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> results = data is List<dynamic>
              ? data
              : (data is Map<String, dynamic> && data['results'] is List<dynamic>
                  ? data['results'] as List<dynamic>
                  : <dynamic>[]);
          return results.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Materials API Error: ${response.statusCode}');
          return null;
        }
      },
    );

    if (result == null) return <MaterialListItem>[];
    return result.map(MaterialListItem.fromJson).toList().cast<MaterialListItem>();
  }

  Future<MaterialsStats> getMaterialsStats() async {
    const cacheKey = 'materials:stats';

    final result = await offlineFirstRead(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/documents/stats/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data as Map<String, dynamic>;
        }
        return null;
      },
    );

    if (result == null) return MaterialsStats();
    return MaterialsStats.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // TEACHER'S CLASSES & SUBJECTS (for pickers)
  // ---------------------------------------------------------------------------

  /// Get classes the current teacher is assigned to
  Future<List<ClassSubjectPair>> getTeacherClassSubjects() async {
    const cacheKey = 'materials:teacher_class_subjects';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/class-subject-teachers/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> results = data is List<dynamic>
              ? data
              : (data is Map<String, dynamic> && data['results'] is List<dynamic>
                  ? data['results'] as List<dynamic>
                  : <dynamic>[]);

          // Deduplicate by class+subject
          final seen = <String>{};
          final pairs = <Map<String, dynamic>>[];
          for (final item in results) {
            if (item is! Map<String, dynamic>) continue;
            final key = '${item['class_obj']}-${item['subject']}';
            if (seen.contains(key)) continue;
            seen.add(key);
            pairs.add(item);
          }
          return pairs;
        }
        return null;
      },
    );

    if (result == null) return [];

    final seen = <String>{};
    final pairs = <ClassSubjectPair>[];
    for (final item in result) {
      final key = '${item['class_obj']}-${item['subject']}';
      if (seen.contains(key)) continue;
      seen.add(key);
      pairs.add(ClassSubjectPair(
        classId: item['class_obj'] is int
            ? item['class_obj'] as int
            : int.tryParse(item['class_obj'].toString()) ?? 0,
        className: item['class_name'] as String? ?? '',
        subjectId: item['subject'] is int
            ? item['subject'] as int
            : int.tryParse(item['subject'].toString()) ?? 0,
        subjectName: item['subject_name'] as String? ?? '',
      ));
    }
    return pairs;
  }

  /// Get list of classes for sharing (all classes in the school)
  Future<List<Map<String, dynamic>>> getAllClasses() async {
    const cacheKey = 'materials:all_classes';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/academics/classes/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> results = data is List<dynamic>
              ? data
              : (data is Map<String, dynamic> && data['results'] is List<dynamic>
                  ? data['results'] as List<dynamic>
                  : <dynamic>[]);
          return results.cast<Map<String, dynamic>>();
        }
        return null;
      },
    );

    return result ?? [];
  }

  // ---------------------------------------------------------------------------
  // CREATE ASSIGNMENT
  // ---------------------------------------------------------------------------

  Future<bool> createAssignment({
    required String title,
    required String description,
    required int classId,
    required int subjectId,
    required DateTime dueDate,
  }) async {
    final payload = {
      'title': title,
      'description': description,
      'class_obj': classId,
      'subject': subjectId,
      'due_date': dueDate.toIso8601String(),
    };
    final entityId = 'assignment:${DateTime.now().millisecondsSinceEpoch}';

    return offlineFirstWrite(
      entityType: 'assignment',
      entityId: entityId,
      endpoint: '/api/assignments/',
      method: 'POST',
      payload: payload,
      cacheKey: 'assignment:$entityId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/api/assignments/'),
          headers: headers,
          body: jsonEncode(payload),
        );
        final ok = response.statusCode >= 200 && response.statusCode < 300;
        if (ok) {
          await NotificationService.instance.showLocalNotification(
            title: 'Assignment Created',
            body: '$title has been created and shared.',
            type: AppNotificationType.assignment,
            payload: {'type': 'assignment', 'title': title, 'class_id': classId},
          );
        }
        return ok;
      },
    );
  }

  Future<bool> deleteAssignment(String assignmentId) async {
    final payload = {'id': assignmentId};

    return offlineFirstWrite(
      entityType: 'assignment',
      entityId: 'assignment:$assignmentId',
      endpoint: '/api/assignments/$assignmentId/',
      method: 'DELETE',
      payload: payload,
      cacheKey: 'assignment:$assignmentId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.delete(
          Uri.parse('$baseUrl/api/assignments/$assignmentId/'),
          headers: headers,
        );
        return response.statusCode >= 200 && response.statusCode < 300;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UPLOAD MATERIAL (multipart)
  // ---------------------------------------------------------------------------

  /// Upload a learning material file along with metadata.
  /// [filePath] is the local path of the picked file.
  Future<int?> uploadMaterial({
    required String title,
    required String description,
    required String filePath,
    String documentType = 'notes',
    int? classId,
    int? subjectId,
    int? folderId,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/academics/documents/'),
      );

      final token = await _authService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['document_type'] = documentType;
      if (classId != null) request.fields['related_class'] = classId.toString();
      if (subjectId != null) request.fields['related_subject'] = subjectId.toString();
      if (folderId != null) request.fields['folder'] = folderId.toString();

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['id'] is int ? body['id'] as int : int.tryParse(body['id'].toString());
      } else {
        debugPrint('Upload material error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Upload material exception: $e');
    }

    final pendingId = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'document_type': documentType,
      if (classId != null) 'related_class': classId,
      if (subjectId != null) 'related_subject': subjectId,
      if (folderId != null) 'folder': folderId,
      'file_path': filePath,
      'offline_only': true,
      'queued_at': DateTime.now().toIso8601String(),
    };

    await offlineFirstWrite(
      entityType: 'material',
      entityId: 'material_upload:$pendingId',
      endpoint: '/api/academics/documents/',
      method: 'POST',
      payload: payload,
      cacheKey: 'material:upload:$pendingId',
      writeFn: () async => false,
    );

    return -pendingId;
  }

  // ---------------------------------------------------------------------------
  // SHARE MATERIAL WITH CLASSES
  // ---------------------------------------------------------------------------

  Future<bool> shareMaterialWithClasses({
    required int documentId,
    required List<int> classIds,
  }) async {
    final payload = {'document_id': documentId, 'class_ids': classIds};
    final entityId = 'share:$documentId';

    return offlineFirstWrite(
      entityType: 'material',
      entityId: entityId,
      endpoint: '/api/academics/documents/$documentId/share_with_classes/',
      method: 'POST',
      payload: payload,
      cacheKey: 'material:share:$documentId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/api/academics/documents/$documentId/share_with_classes/'),
          headers: headers,
          body: jsonEncode({'class_ids': classIds}),
        );
        final ok = response.statusCode >= 200 && response.statusCode < 300;
        if (ok) {
          await NotificationService.instance.showLocalNotification(
            title: 'Material Shared',
            body: 'Study material has been shared with ${classIds.length} class(es).',
            type: AppNotificationType.material,
            payload: {'type': 'material', 'document_id': documentId, 'class_ids': classIds},
          );
        }
        return ok;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE MATERIAL
  // ---------------------------------------------------------------------------

  Future<bool> deleteMaterial(int documentId) async {
    final payload = {'id': documentId};

    return offlineFirstWrite(
      entityType: 'material',
      entityId: 'material:$documentId',
      endpoint: '/api/academics/documents/$documentId/',
      method: 'DELETE',
      payload: payload,
      cacheKey: 'material:$documentId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.delete(
          Uri.parse('$baseUrl/api/academics/documents/$documentId/'),
          headers: headers,
        );
        return response.statusCode >= 200 && response.statusCode < 300;
      },
    );
  }
}
