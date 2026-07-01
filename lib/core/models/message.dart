class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String receiverName;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.senderName = '',
    this.receiverName = '',
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'].toString(),
    senderId: json['sender_id'].toString(),
    receiverId: json['receiver_id'].toString(),
    senderName: json['sender_name'] as String? ?? '',
    receiverName: json['receiver_name'] as String? ?? '',
    content: json['content'] as String? ?? '',
    isRead: json['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'receiver_id': receiverId,
    'sender_name': senderName,
    'receiver_name': receiverName,
    'content': content,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };
}
