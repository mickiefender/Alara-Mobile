import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'package:alara/core/api_config.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/core/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

enum AppNotificationType {
  announcement,
  message,
  notice,
  attendance,
  material,
  grading,
  assignment,
  fees,
  generic,
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;
  bool isRead;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.payload,
    this.isRead = false,
  });
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;
  final List<InAppNotificationItem> _inAppNotifications = [];
  
  // Backend sync timer for real-time updates
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 30);

  String? get fcmToken => _fcmToken;
  List<InAppNotificationItem> get notifications =>
      List.unmodifiable(_inAppNotifications);
  int get unreadCount => _inAppNotifications.where((n) => !n.isRead).length;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'alara_high_importance',
    'Alara Notifications',
    description:
        'Announcements, attendance, assignments, grading, fees, and messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ---------------- INIT ----------------

  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermission();
    await _setupForegroundHandlers();
    await _createAndroidChannel();

    _initialized = true;
  }

  Future<void> initFcmToken() async {
    try {
      final token = await _messaging.getToken();

      if (token != null) {
        _fcmToken = token;
        debugPrint("🔥 FCM TOKEN READY: $token");
      } else {
        debugPrint("⚠️ FCM token is null (Firebase still initializing)");
      }

      // Listen for refresh automatically (VERY IMPORTANT)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint("♻️ FCM TOKEN REFRESHED: $newToken");
      });
    } catch (e) {
      debugPrint("❌ FCM token error: $e");
    }
  }

  // ---------------- LOCAL NOTIFS ----------------

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notification tapped: ${response.payload}");
      },
    );
  }

  Future<void> _createAndroidChannel() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(_channel);
  }

  // ---------------- PERMISSION ----------------

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint("🔔 Permission: ${settings.authorizationStatus}");
  }

  // ---------------- HANDLERS ----------------

  Future<void> _setupForegroundHandlers() async {
    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? "New Notification";
      final body = message.notification?.body ?? "";
      final type = _parseType(message.data['type']?.toString());

      addInAppNotification(
        title: title,
        body: body,
        type: type,
        payload: message.data,
      );

      await showLocalNotification(
        title: title,
        body: body,
        type: type,
        payload: message.data,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint("📲 Notification opened: ${message.data}");
    });
  }

  // ---------------- TOPICS ----------------

  Future<void> subscribeForUser(User user) async {
    if (!_initialized) return;

    try {
      await _messaging.subscribeToTopic('all_users');
      await _messaging.subscribeToTopic('role_${user.role}');
      await _messaging.subscribeToTopic('user_${user.id}');

      if (user.classId != null && user.classId!.isNotEmpty) {
        await _messaging.subscribeToTopic('class_${user.classId}');
      }

      await _syncTokenToBackend(user.id);
    } catch (e) {
      debugPrint("❌ Topic subscribe error: $e");
    }
  }

  Future<void> unsubscribeForUser(User user) async {
    if (!_initialized) return;

    try {
      await _messaging.unsubscribeFromTopic('role_${user.role}');
      await _messaging.unsubscribeFromTopic('user_${user.id}');

      if (user.classId != null && user.classId!.isNotEmpty) {
        await _messaging.unsubscribeFromTopic('class_${user.classId}');
      }
    } catch (e) {
      debugPrint("❌ Topic unsubscribe error: $e");
    }
  }

  // ---------------- BACKEND SYNC ----------------

  Future<void> _syncTokenToBackend(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      _fcmToken = token;

      final authService = AuthService();
      final jwt = await authService.getToken();

      final payload = jsonEncode({
        'user_id': userId,
        'fcm_token': token,
        'platform': defaultTargetPlatform.name,
      });

      debugPrint("📦 Token payload ready: $payload");

      // TODO: send to backend API
    } catch (e) {
      debugPrint("❌ Backend sync error: $e");
    }
  }

  // ---------------- LOCAL NOTIFICATION ----------------

  Future<void> showLocalNotification({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.generic,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      _prefix(type, title),
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ---------------- IN-APP FEED ----------------

  void addInAppNotification({
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.generic,
    Map<String, dynamic>? payload,
  }) {
    final item = InAppNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _prefix(type, title),
      body: body,
      type: type,
      createdAt: DateTime.now(),
      payload: payload,
    );

    _inAppNotifications.insert(0, item);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _inAppNotifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    if (_inAppNotifications[index].isRead) return;

    _inAppNotifications[index].isRead = true;
    notifyListeners();
  }

  void markAllAsRead() {
    bool changed = false;
    for (final n in _inAppNotifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
if (changed) {
      notifyListeners();
    }
  }

  void clearAll() {
    if (_inAppNotifications.isEmpty) return;
    _inAppNotifications.clear();
    notifyListeners();
  }
  
  // ---------------- BACKEND SYNC ----------------
  
  /// Start polling backend for real-time notification updates
  void startBackendSync() {
    stopBackendSync();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _syncFromBackend());
    // Also do immediate sync
    _syncFromBackend();
  }
  
  /// Stop polling backend
  void stopBackendSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
  
  /// Fetch notifications from backend API
  Future<void> _syncFromBackend() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) return;
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> backendNotifs = data['results'] ?? data ?? [];
        
        // Merge backend notifications with local ones
        for (final notif in backendNotifs) {
          final existingIndex = _inAppNotifications.indexWhere(
            (n) => n.id == notif['id'].toString(),
          );
          
          if (existingIndex == -1) {
            // New notification from backend
            final typeStr = notif['notification_type']?.toString() ?? 'generic';
            final type = _parseBackendType(typeStr);
            
            _inAppNotifications.insert(
              0,
              InAppNotificationItem(
                id: notif['id'].toString(),
                title: notif['title'] ?? '',
                body: notif['message'] ?? '',
                type: type,
                createdAt: notif['created_at'] != null
                    ? DateTime.tryParse(notif['created_at']) ?? DateTime.now()
                    : DateTime.now(),
                payload: notif,
                isRead: notif['is_read'] ?? false,
              ),
            );
          }
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Backend sync error: $e");
    }
  }
  
  /// Parse backend notification type to app type
  AppNotificationType _parseBackendType(String type) {
    switch (type.toLowerCase()) {
      case 'announcement':
        return AppNotificationType.announcement;
      case 'message':
        return AppNotificationType.message;
      case 'notice':
        return AppNotificationType.notice;
      case 'attendance':
        return AppNotificationType.attendance;
      case 'material':
        return AppNotificationType.material;
      case 'grading':
      case 'grade':
        return AppNotificationType.grading;
      case 'assignment':
        return AppNotificationType.assignment;
      case 'fee':
      case 'fees':
        return AppNotificationType.fees;
      default:
        return AppNotificationType.generic;
    }
  }

  // ---------------- HELPERS ----------------

  AppNotificationType _parseType(String? type) {
    switch (type) {
      case 'announcement':
        return AppNotificationType.announcement;
      case 'message':
        return AppNotificationType.message;
      case 'notice':
        return AppNotificationType.notice;
      case 'attendance':
        return AppNotificationType.attendance;
      case 'material':
        return AppNotificationType.material;
      case 'grading':
        return AppNotificationType.grading;
      case 'assignment':
        return AppNotificationType.assignment;
      case 'fees':
        return AppNotificationType.fees;
      default:
        return AppNotificationType.generic;
    }
  }

  String _prefix(AppNotificationType type, String title) {
    switch (type) {
      case AppNotificationType.announcement:
        return "📢 $title";
      case AppNotificationType.message:
        return "💬 $title";
      case AppNotificationType.notice:
        return "📝 $title";
      case AppNotificationType.attendance:
        return "✅ $title";
      case AppNotificationType.material:
        return "📚 $title";
      case AppNotificationType.grading:
        return "📊 $title";
      case AppNotificationType.assignment:
        return "🧩 $title";
      case AppNotificationType.fees:
        return "💳 $title";
      case AppNotificationType.generic:
        return title;
    }
  }
}