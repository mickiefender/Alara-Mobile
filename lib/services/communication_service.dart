import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/models/message.dart';
import 'package:alara/core/models/announcement.dart';
import 'package:alara/core/offline/offline_service_mixin.dart';
import 'package:alara/core/services/notification_service.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String senderId;
  final String senderName;
  final String priority;
  final String? targetRole;
  final bool isRead;
  final bool isPinned;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.priority,
    this.targetRole,
    this.isRead = false,
    this.isPinned = false,
    required this.createdAt,
  });

factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'].toString(),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    senderId: json['created_by']?.toString() ?? '',
    senderName: json['created_by_name'] as String? ?? 'School Admin',
    priority: json['priority'] as String? ?? 'medium',
    targetRole: json['send_to_teachers'] == true
        ? 'teacher'
        : json['send_to_students'] == true
            ? 'student'
            : json['send_to_all'] == true
                ? 'all'
                : null,
    isRead: json['is_read'] as bool? ?? false,
    isPinned: json['is_pinned'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Notice copyWith({bool? isRead}) => Notice(
    id: id,
    title: title,
    content: content,
    senderId: senderId,
    senderName: senderName,
    priority: priority,
    targetRole: targetRole,
    isRead: isRead ?? this.isRead,
    isPinned: isPinned,
    createdAt: createdAt,
  );
}

class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserRole;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserRole,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory Conversation.fromMessage(Message message, String otherUserId, String otherUserName) => Conversation(
    id: message.senderId == otherUserId ? message.senderId : message.receiverId,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    lastMessage: message.content,
    lastMessageAt: message.createdAt,
    unreadCount: message.isRead ? 0 : 1,
  );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'].toString(),
    otherUserId: json['other_user_id'].toString(),
    otherUserName: json['other_user_name'] as String? ?? 'Unknown',
    otherUserAvatar: json['other_user_avatar'] as String?,
    otherUserRole: json['other_user_role'] as String?,
    lastMessage: json['last_message'] as String? ?? '',
    lastMessageAt: DateTime.parse(json['last_message_at'] as String),
    unreadCount: json['unread_count'] as int? ?? 0,
    isOnline: json['is_online'] as bool? ?? false,
  );
}

class CommunicationService with OfflineAwareService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Messages ───────────────────────────────────────────────────

  /// Fetch received messages from the backend
  Future<List<Message>> getReceivedMessages() async {
    const cacheKey = 'communication:messages:received';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/messaging/messages/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? (data is List ? data : []);
          return results.cast<Map<String, dynamic>>();
        }
        return null;
      },
    );

    if (result == null) return [];
    return result.map((m) => _backendMessageToFrontend(m)).toList();
  }

  /// Fetch sent messages
  Future<List<Message>> getSentMessages() async {
    const cacheKey = 'communication:messages:sent';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/messaging/messages/sent/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> results = data is List ? data : [];
          return results.cast<Map<String, dynamic>>();
        }
        return null;
      },
    );

    if (result == null) return [];
    return result.map((m) => _backendMessageToFrontend(m)).toList();
  }

  /// Build conversation list from received messages (grouped by sender)
  Future<List<Conversation>> getConversations() async {
    try {
      final messages = await getReceivedMessages();
      final sentMessages = await getSentMessages();

      // Group received messages by sender
      final Map<String, List<Message>> grouped = {};
      for (final msg in messages) {
        grouped.putIfAbsent(msg.senderId, () => []).add(msg);
      }

      // Build conversations from grouped messages
      final conversations = <Conversation>[];
      for (final entry in grouped.entries) {
        entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latest = entry.value.first;
        final unreadCount = entry.value.where((m) => !m.isRead).length;
        conversations.add(Conversation(
          id: entry.key,
          otherUserId: entry.key,
          otherUserName: latest.senderName.isNotEmpty ? latest.senderName : 'User ${entry.key}',
          lastMessage: latest.content,
          lastMessageAt: latest.createdAt,
          unreadCount: unreadCount,
        ));
      }

      // Also include sent messages grouped by recipient
      final Map<String, List<Message>> sentGrouped = {};
      for (final msg in sentMessages) {
        sentGrouped.putIfAbsent(msg.receiverId, () => []).add(msg);
      }
      for (final entry in sentGrouped.entries) {
        entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latest = entry.value.first;
        final existingIdx = conversations.indexWhere((c) => c.otherUserId == entry.key);
        if (existingIdx == -1) {
          conversations.add(Conversation(
            id: entry.key,
            otherUserId: entry.key,
            otherUserName: latest.receiverName.isNotEmpty ? latest.receiverName : 'User ${entry.key}',
            lastMessage: latest.content,
            lastMessageAt: latest.createdAt,
            unreadCount: 0,
          ));
        }
      }

      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return conversations;
    } catch (e) {
      debugPrint('getConversations Error: $e');
      return [];
    }
  }

  /// Get messages for a specific conversation (by user ID)
  Future<List<Message>> getMessages(String otherUserId, {int page = 1}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messaging/messages/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? (data is List ? data : []);
        final allMessages = results.map((m) => _backendMessageToFrontend(m as Map<String, dynamic>)).toList();

        // Filter messages involving this user
        final filtered = allMessages.where((m) =>
            m.senderId == otherUserId || m.receiverId == otherUserId).toList();
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return filtered;
      }
      return [];
    } catch (e) {
      debugPrint('getMessages Error: $e');
      return [];
    }
  }

  /// Send a message
  Future<bool> sendMessage(String receiverId, String content, {String? subject}) async {
    final payload = <String, dynamic>{
      'recipient': int.tryParse(receiverId) ?? receiverId,
      'subject': subject ?? 'New Message',
      'content': content,
    };
    final entityId = 'message:${DateTime.now().millisecondsSinceEpoch}';

    return offlineFirstWrite(
      entityType: 'message',
      entityId: entityId,
      endpoint: '/api/messaging/messages/',
      method: 'POST',
      payload: payload,
      cacheKey: 'communication:outbox:$entityId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/api/messaging/messages/'),
          headers: headers,
          body: jsonEncode(payload),
        );
        if (response.statusCode == 201) {
          await NotificationService.instance.showLocalNotification(
            title: 'Message Sent',
            body: 'Your message has been sent successfully.',
            type: AppNotificationType.message,
            payload: {'type': 'message', 'receiver_id': receiverId},
          );
          return true;
        }
        return false;
      },
    );
  }

  /// Start a conversation (send first message)
  Future<bool> startConversation(String receiverId, String content) async {
    return sendMessage(receiverId, content);
  }

  /// Mark all messages from a user as read
  Future<bool> markAsRead(String otherUserId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/messaging/messages/$otherUserId/mark_as_read/'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markAsRead Error: $e');
      return false;
    }
  }

  // ─── Announcements ──────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements() async {
    const cacheKey = 'communication:announcements:list';

    final result = await offlineFirstReadList(
      cacheKey: cacheKey,
      fetchFn: () async {
        final headers = await _getHeaders();
        final response = await http.get(
          Uri.parse('$baseUrl/api/messaging/announcements/'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? (data is List ? data : []);
          return results.cast<Map<String, dynamic>>();
        }
        return null;
      },
    );

    if (result == null) return [];
    return result.map((a) => _backendAnnouncementToFrontend(a)).toList();
  }

  Future<bool> postAnnouncement({
    required String title,
    required String message,
    String? targetRole,
    String? targetClassId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'content': message,
      'send_to_all': true,
    };

    // Map targetRole to backend fields
    if (targetRole == 'teacher') {
      body['send_to_teachers'] = true;
      body['send_to_all'] = false;
    } else if (targetRole == 'student') {
      body['send_to_students'] = true;
      body['send_to_all'] = false;
    }
    if (targetClassId != null) {
      body['classes'] = [int.tryParse(targetClassId) ?? targetClassId];
    }

    final entityId = 'announcement:${DateTime.now().millisecondsSinceEpoch}';

    return offlineFirstWrite(
      entityType: 'announcement',
      entityId: entityId,
      endpoint: '/api/messaging/announcements/',
      method: 'POST',
      payload: body,
      cacheKey: 'communication:announcements:outbox:$entityId',
      writeFn: () async {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/api/messaging/announcements/'),
          headers: headers,
          body: jsonEncode(body),
        );
        if (response.statusCode == 201) {
          await NotificationService.instance.showLocalNotification(
            title: 'Announcement Posted',
            body: title,
            type: AppNotificationType.announcement,
            payload: {'type': 'announcement', 'title': title},
          );
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> markAnnouncementRead(String announcementId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/messaging/announcements/$announcementId/mark_as_read/'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markAnnouncementRead Error: $e');
      return false;
    }
  }

  // ─── Notices ────────────────────────────────────────────────────

  Future<List<Notice>> getNotices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/messaging/notices/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? (data is List ? data : []);
        return results.map((n) => Notice.fromJson(n as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('getNotices Error: $e');
      return [];
    }
  }

  Future<bool> postNotice({
    required String title,
    required String content,
    String? priority,
    String? targetRole,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'title': title,
        'content': content,
        'priority': priority ?? 'medium',
        'send_to_all': true,
      };

      if (targetRole == 'teacher') {
        body['send_to_teachers'] = true;
        body['send_to_all'] = false;
      } else if (targetRole == 'student') {
        body['send_to_students'] = true;
        body['send_to_all'] = false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/messaging/notices/'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        await NotificationService.instance.showLocalNotification(
          title: 'Notice Published',
          body: title,
          type: AppNotificationType.notice,
          payload: {'type': 'notice', 'title': title},
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('postNotice Error: $e');
      return false;
    }
  }

  Future<bool> markNoticeRead(String noticeId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/messaging/notices/$noticeId/mark_as_read/'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('markNoticeRead Error: $e');
      return false;
    }
  }

  // ─── Helpers to map backend models ──────────────────────────────

  /// Convert backend Message response to frontend Message model
  Message _backendMessageToFrontend(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      senderId: json['sender'].toString(),
      receiverId: json['recipient'].toString(),
      senderName: json['sender_name'] as String? ?? '',
      receiverName: json['recipient_name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

/// Convert backend Announcement response to frontend Announcement model
  Announcement _backendAnnouncementToFrontend(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdByName: json['created_by_name'] as String?,
      readCount: json['read_count'] as int? ?? 0,
      status: json['status'] as String?,
      createdAt: DateTime.parse(
        json['published_date'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      publishedDate: json['published_date'] != null 
          ? DateTime.tryParse(json['published_date'] as String) 
          : null,
    );
  }
}
