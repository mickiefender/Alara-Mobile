class Grade {
  final String id;
  final String studentId;
  final String subject;
  final String examType;
  final double score;
  final double maxScore;
  final String semester;
  final DateTime createdAt;
  final DateTime updatedAt;

  Grade({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.examType,
    required this.score,
    required this.maxScore,
    required this.semester,
    required this.createdAt,
    required this.updatedAt,
  });

  double get percentage => (score / maxScore) * 100;

  String get letterGrade {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  factory Grade.fromJson(Map<String, dynamic> json) => Grade(
    id: json['id'].toString(),
    studentId: json['student_id'].toString(),
    subject: json['subject'] as String,
    examType: json['exam_type'] as String,
    score: (json['score'] as num).toDouble(),
    maxScore: (json['max_score'] as num).toDouble(),
    semester: json['semester'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'subject': subject,
    'exam_type': examType,
    'score': score,
    'max_score': maxScore,
    'semester': semester,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
