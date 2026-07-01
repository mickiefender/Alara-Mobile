class TimetableEntry {
  final int id;
  final int classObjId;
  final int subjectId;
  final int? teacherId;
  final String day;
  final String startTime;
  final String endTime;
  final String? venue;
  final String? subjectName;
  final String? className;
  final String? teacherName;
  final String? createdAt;
  final String? updatedAt;

  TimetableEntry({
    required this.id,
    required this.classObjId,
    required this.subjectId,
    this.teacherId,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.venue,
    this.subjectName,
    this.className,
    this.teacherName,
    this.createdAt,
    this.updatedAt,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      classObjId: json['class_obj'] is int ? json['class_obj'] : int.tryParse(json['class_obj'].toString()) ?? 0,
      subjectId: json['subject'] is int ? json['subject'] : int.tryParse(json['subject'].toString()) ?? 0,
      teacherId: json['teacher'] != null
          ? (json['teacher'] is int ? json['teacher'] : int.tryParse(json['teacher'].toString()))
          : null,
      day: (json['day'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      venue: json['venue']?.toString(),
      subjectName: json['subject_name']?.toString(),
      className: json['class_name']?.toString(),
      teacherName: json['teacher_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
