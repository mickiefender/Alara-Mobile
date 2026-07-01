class Assignment {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String teacherId;
  final String subject;
  final DateTime dueDate;
  final String? fileUrl;
  final List<AssignmentSubmission> submissions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.classId,
    required this.teacherId,
    required this.subject,
    required this.dueDate,
    this.fileUrl,
    this.submissions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json['id'].toString(),
    title: json['title'] as String,
    description: json['description'] as String,
    classId: json['class_id'].toString(),
    teacherId: json['teacher_id'].toString(),
    subject: json['subject'] as String,
    dueDate: DateTime.parse(json['due_date'] as String),
    fileUrl: json['file_url'] as String?,
    submissions: (json['submissions'] as List<dynamic>?)
        ?.map((e) => AssignmentSubmission.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'class_id': classId,
    'teacher_id': teacherId,
    'subject': subject,
    'due_date': dueDate.toIso8601String(),
    'file_url': fileUrl,
    'submissions': submissions.map((e) => e.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String? fileUrl;
  final String? grade;
  final String? feedback;
  final DateTime submittedAt;

  AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.fileUrl,
    this.grade,
    this.feedback,
    required this.submittedAt,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) => AssignmentSubmission(
    id: json['id'].toString(),
    assignmentId: json['assignment_id'].toString(),
    studentId: json['student_id'].toString(),
    fileUrl: json['file_url'] as String?,
    grade: json['grade']?.toString(),
    feedback: json['feedback'] as String?,
    submittedAt: DateTime.parse(json['submitted_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assignment_id': assignmentId,
    'student_id': studentId,
    'file_url': fileUrl,
    'grade': grade,
    'feedback': feedback,
    'submitted_at': submittedAt.toIso8601String(),
  };
}
