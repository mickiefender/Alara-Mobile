/// Frontend model matching the Django backend students_Grade model.
/// Assessment types: exam, test, quiz, continuous, assignment
class GradeRecord {
  final int id;
  final int student;
  final int subject;
  final String? subjectName;
  final String? studentName;
  final String assessmentType;
  final double score;
  final double maxScore;
  final double percentage;
  final String grade;
  final bool isLocked;
  final int? academicSession;
  final String? recordedDate;
  final String? createdAt;
  final String? updatedAt;
  final double? assessmentTypeMaxScore;

  GradeRecord({
    required this.id,
    required this.student,
    required this.subject,
    this.subjectName,
    this.studentName,
    required this.assessmentType,
    required this.score,
    this.maxScore = 100,
    this.percentage = 0,
    this.grade = '',
    this.isLocked = false,
    this.academicSession,
    this.recordedDate,
    this.createdAt,
    this.updatedAt,
    this.assessmentTypeMaxScore = 100,
  });

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    return GradeRecord(
      id: json['id'] ?? 0,
      student: json['student'] ?? 0,
      subject: json['subject'] ?? 0,
      subjectName: json['subject_name'] as String?,
      studentName: json['student_name'] as String?,
      assessmentType: json['assessment_type'] as String? ?? 'exam',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 100,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] as String? ?? '',
      isLocked: json['is_locked'] ?? false,
      academicSession: json['academic_session'] as int?,
      recordedDate: json['recorded_date'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      assessmentTypeMaxScore: (json['assessment_type_max_score'] as num?)?.toDouble() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != 0) 'id': id,
    'student': student,
    'subject': subject,
    'assessment_type': assessmentType,
    'score': score,
    'max_score': maxScore,
    if (academicSession != null) 'academic_session': academicSession,
    if (recordedDate != null && recordedDate!.isNotEmpty) 'recorded_date': recordedDate,
  };
}

/// Class/subject/student data returned by the grade_entry_data endpoint.
class GradeEntryData {
  final int classId;
  final List<StudentInfo> students;
  final List<SubjectInfo> subjects;
  final bool isFormTutor;

  GradeEntryData({
    required this.classId,
    required this.students,
    required this.subjects,
    required this.isFormTutor,
  });

  factory GradeEntryData.fromJson(Map<String, dynamic> json) {
    return GradeEntryData(
      classId: json['class_id'] ?? 0,
      students: (json['students'] as List? ?? [])
          .map((s) => StudentInfo.fromJson(s))
          .toList(),
      subjects: (json['subjects'] as List? ?? [])
          .map((s) => SubjectInfo.fromJson(s))
          .toList(),
      isFormTutor: json['is_form_tutor'] ?? false,
    );
  }
}

class StudentInfo {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? email;

  StudentInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.email,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      id: json['id'] ?? 0,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
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
      id: json['id'] ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }
}
