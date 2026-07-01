class Notice {
  final String id;
  final String title;
  final String content;
  final String? createdByName;
  final String priority;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? expiryDate;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    this.createdByName,
    this.priority = 'medium',
    this.isPinned = false,
    required this.createdAt,
    this.expiryDate,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'].toString(),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdByName: json['created_by_name'] as String?,
    priority: json['priority'] as String? ?? 'medium',
    isPinned: json['is_pinned'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    expiryDate: json['expiry_date'] != null 
        ? DateTime.tryParse(json['expiry_date'] as String) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_by_name': createdByName,
    'priority': priority,
    'is_pinned': isPinned,
    'created_at': createdAt.toIso8601String(),
    'expiry_date': expiryDate?.toIso8601String(),
  };
}

class PersonalNotice {
  final String id;
  final String title;
  final String content;
  final String? createdByName;
  final String? studentName;
  final DateTime sentAt;

  PersonalNotice({
    required this.id,
    required this.title,
    required this.content,
    this.createdByName,
    this.studentName,
    required this.sentAt,
  });

  factory PersonalNotice.fromJson(Map<String, dynamic> json) => PersonalNotice(
    id: json['id'].toString(),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdByName: json['created_by_name'] as String?,
    studentName: json['student_name'] as String?,
    sentAt: DateTime.parse(json['sent_at'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_by_name': createdByName,
    'student_name': studentName,
    'sent_at': sentAt.toIso8601String(),
  };
}
