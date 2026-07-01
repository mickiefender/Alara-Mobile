class Announcement {
  final String id;
  final String title;
  final String content;
  final String? createdByName;
  final int readCount;
  final String? status;
  final DateTime createdAt;
  final DateTime? publishedDate;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.createdByName,
    this.readCount = 0,
    this.status,
    required this.createdAt,
    this.publishedDate,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'].toString(),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdByName: json['created_by_name'] as String?,
    readCount: json['read_count'] as int? ?? 0,
    status: json['status'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String? ?? json['published_date'] as String? ?? DateTime.now().toIso8601String()),
    publishedDate: json['published_date'] != null ? DateTime.parse(json['published_date'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_by_name': createdByName,
    'read_count': readCount,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'published_date': publishedDate?.toIso8601String(),
  };
}
