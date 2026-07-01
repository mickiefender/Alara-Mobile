/// Frontend model for the backend Assessment model.
/// Represents a specific graded assessment (test, exam, assignment, etc.)
/// with a title, subject, class, academic session, term, category, total marks, date, and weight.
class Assessment {
  final int id;
  final int school;
  final String title;
  final int subject;
  final String? subjectName;
  final int classObj;
  final String? className;
  final int academicSession;
  final String? sessionName;
  final int term;
  final String category; // 'continuous_assessment' or 'examination'
  final double totalMarks;
  final String assessmentDate;
  final double weightPercentage;
  final bool isActive;
  final int? createdBy;
  final String? createdByName;
  final String? createdAt;
  final String? updatedAt;

  Assessment({
    required this.id,
    required this.school,
    required this.title,
    required this.subject,
    this.subjectName,
    required this.classObj,
    this.className,
    required this.academicSession,
    this.sessionName,
    required this.term,
    required this.category,
    this.totalMarks = 100,
    required this.assessmentDate,
    this.weightPercentage = 0,
    this.isActive = true,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  String get categoryLabel =>
      category == 'continuous_assessment' ? 'Continuous Assessment' : 'Examination';

  String get termLabel {
    switch (term) {
      case 1: return 'First Term';
      case 2: return 'Second Term';
      case 3: return 'Third Term';
      default: return 'Term $term';
    }
  }

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'] ?? 0,
      school: json['school'] ?? 0,
      title: json['title'] ?? '',
      subject: json['subject'] ?? 0,
      subjectName: json['subject_name'] as String?,
      classObj: json['class_obj'] ?? 0,
      className: json['class_name'] as String?,
      academicSession: json['academic_session'] ?? 0,
      sessionName: json['session_name'] as String?,
      term: json['term'] ?? 1,
      category: json['category'] ?? 'continuous_assessment',
      totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 100,
      assessmentDate: json['assessment_date'] ?? '',
      weightPercentage: (json['weight_percentage'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'] as int?,
      createdByName: json['created_by_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != 0) 'id': id,
    'title': title,
    'subject': subject,
    'class_obj': classObj,
    'academic_session': academicSession,
    'term': term,
    'category': category,
    'total_marks': totalMarks,
    'assessment_date': assessmentDate,
    'weight_percentage': weightPercentage,
    'is_active': isActive,
  };
}

/// Response from the bulk_save_scores endpoint
class BulkScoreResult {
  final int assessmentId;
  final String assessmentTitle;
  final List<StudentScoreResult> results;
  final List<Map<String, dynamic>> errors;
  final int successCount;
  final int errorCount;

  BulkScoreResult({
    required this.assessmentId,
    required this.assessmentTitle,
    required this.results,
    required this.errors,
    required this.successCount,
    required this.errorCount,
  });

  factory BulkScoreResult.fromJson(Map<String, dynamic> json) {
    return BulkScoreResult(
      assessmentId: json['assessment_id'] ?? 0,
      assessmentTitle: json['assessment_title'] ?? '',
      results: (json['results'] as List? ?? [])
          .map((s) => StudentScoreResult.fromJson(s))
          .toList(),
      errors: (json['errors'] as List? ?? []).cast<Map<String, dynamic>>(),
      successCount: json['success_count'] ?? 0,
      errorCount: json['error_count'] ?? 0,
    );
  }
}

class StudentScoreResult {
  final int studentId;
  final int gradeId;
  final double score;
  final double percentage;
  final String grade;
  final bool wasCreated;

  StudentScoreResult({
    required this.studentId,
    required this.gradeId,
    required this.score,
    required this.percentage,
    required this.grade,
    required this.wasCreated,
  });

  factory StudentScoreResult.fromJson(Map<String, dynamic> json) {
    return StudentScoreResult(
      studentId: json['student_id'] ?? 0,
      gradeId: json['grade_id'] ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] ?? '',
      wasCreated: json['was_created'] ?? false,
    );
  }
}

/// Response from assessment_scores endpoint - scores per student for an assessment
class AssessmentScoresResponse {
  final Assessment assessment;
  final List<StudentScoreEntry> students;
  final int totalStudents;
  final int gradedCount;

  AssessmentScoresResponse({
    required this.assessment,
    required this.students,
    required this.totalStudents,
    required this.gradedCount,
  });

  factory AssessmentScoresResponse.fromJson(Map<String, dynamic> json) {
    return AssessmentScoresResponse(
      assessment: Assessment.fromJson(json['assessment']),
      students: (json['students'] as List? ?? [])
          .map((s) => StudentScoreEntry.fromJson(s))
          .toList(),
      totalStudents: json['total_students'] ?? 0,
      gradedCount: json['graded_count'] ?? 0,
    );
  }
}

class StudentScoreEntry {
  final int studentId;
  final String studentName;
  final String firstName;
  final String lastName;
  final double? score;
  final int? gradeId;
  final double? percentage;
  final String? gradeLetter;
  final bool hasScore;

  StudentScoreEntry({
    required this.studentId,
    required this.studentName,
    required this.firstName,
    required this.lastName,
    this.score,
    this.gradeId,
    this.percentage,
    this.gradeLetter,
    this.hasScore = false,
  });

  factory StudentScoreEntry.fromJson(Map<String, dynamic> json) {
    return StudentScoreEntry(
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      score: (json['score'] as num?)?.toDouble(),
      gradeId: json['grade_id'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      gradeLetter: json['grade_letter'] as String?,
      hasScore: json['has_score'] ?? false,
    );
  }
}

/// Response from compute_results endpoint
class ComputedResults {
  final int classId;
  final int? subjectId;
  final int? academicSessionId;
  final String? term;
  final List<StudentResult> results;
  final int totalStudents;
  final ResultSummary summary;

  ComputedResults({
    required this.classId,
    this.subjectId,
    this.academicSessionId,
    this.term,
    required this.results,
    required this.totalStudents,
    required this.summary,
  });

  factory ComputedResults.fromJson(Map<String, dynamic> json) {
    return ComputedResults(
      classId: json['class_id'] ?? 0,
      subjectId: json['subject_id'] as int?,
      academicSessionId: json['academic_session_id'] as int?,
      term: json['term'] as String?,
      results: (json['results'] as List? ?? [])
          .map((r) => StudentResult.fromJson(r))
          .toList(),
      totalStudents: json['total_students'] ?? 0,
      summary: ResultSummary.fromJson(json['summary']),
    );
  }
}

class StudentResult {
  final int studentId;
  final String studentName;
  final double caScore;
  final double examScore;
  final double examMax;
  final double examPercentage;
  final double finalScore;
  final double percentage;
  final String grade;
  final String remark;
  final int position;

  StudentResult({
    required this.studentId,
    required this.studentName,
    required this.caScore,
    required this.examScore,
    required this.examMax,
    required this.examPercentage,
    required this.finalScore,
    required this.percentage,
    required this.grade,
    required this.remark,
    required this.position,
  });

  factory StudentResult.fromJson(Map<String, dynamic> json) {
    return StudentResult(
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      caScore: (json['ca_score'] as num?)?.toDouble() ?? 0,
      examScore: (json['exam_score'] as num?)?.toDouble() ?? 0,
      examMax: (json['exam_max'] as num?)?.toDouble() ?? 0,
      examPercentage: (json['exam_percentage'] as num?)?.toDouble() ?? 0,
      finalScore: (json['final_score'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] ?? '',
      remark: json['remark'] ?? '',
      position: json['position'] ?? 0,
    );
  }
}

class ResultSummary {
  final double highestScore;
  final double lowestScore;
  final double averageScore;

  ResultSummary({
    required this.highestScore,
    required this.lowestScore,
    required this.averageScore,
  });

  factory ResultSummary.fromJson(Map<String, dynamic> json) {
    return ResultSummary(
      highestScore: (json['highest_score'] as num?)?.toDouble() ?? 0,
      lowestScore: (json['lowest_score'] as num?)?.toDouble() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
