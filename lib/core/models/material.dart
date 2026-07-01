class LearningMaterial {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String classId;
  final String teacherId;
  final String fileUrl;
  final String fileType;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.classId,
    required this.teacherId,
    required this.fileUrl,
    required this.fileType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LearningMaterial.fromJson(Map<String, dynamic> json) => LearningMaterial(
    id: json['id'].toString(),
    title: json['title'] as String,
    description: json['description'] as String,
    subject: json['subject'] as String,
    classId: json['class_id'].toString(),
    teacherId: json['teacher_id'].toString(),
    fileUrl: json['file_url'] as String,
    fileType: json['file_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'subject': subject,
    'class_id': classId,
    'teacher_id': teacherId,
    'file_url': fileUrl,
    'file_type': fileType,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
