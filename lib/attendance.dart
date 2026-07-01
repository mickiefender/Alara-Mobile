class Attendance {
  final String id;
  final String studentId;
  final String classId;
  final DateTime date;
  final String status;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  Attendance({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.status,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    id: json['id'].toString(),
    studentId: json['student_id'].toString(),
    classId: json['class_id'].toString(),
    date: DateTime.parse(json['date'] as String),
    status: json['status'] as String,
    remarks: json['remarks'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'class_id': classId,
    'date': date.toIso8601String().split('T')[0],
    'status': status,
    'remarks': remarks,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Attendance copyWith({
    String? id,
    String? studentId,
    String? classId,
    DateTime? date,
    String? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Attendance(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    classId: classId ?? this.classId,
    date: date ?? this.date,
    status: status ?? this.status,
    remarks: remarks ?? this.remarks,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
