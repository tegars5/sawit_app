import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/admin/screens/admin_order_detail_screen.dart';
import '../api/api_client.dart';
import 'storage_service.dart';

// Background Handler must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('🔔 User granted permission: ${settings.authorizationStatus}');

    // Check if permission is denied
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Permission DENIED. Notifications will not be shown.');
      print('👉 Please enable notifications in App Settings manually.');
    }

    // 2. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Simple iOS init
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle local notification tap
        if (details.payload != null) {
          print("Notification tapped: ${details.payload}");
        }
      },
    );

    // Create Channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Foreground Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground Message Received");
      print("   MessageID: ${message.messageId}");
      print("   Notification: ${message.notification}");
      print("   Data: ${message.data}");

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      String? title;
      String? body;

      // Extract content
      if (notification != null) {
        title = notification.title;
        body = notification.body;
      } else {
        // Fallback to data if notification is null
        title = message.data['title'];
        body = message.data['body'];
      }

      // Show Local Notification if we have content
      if (title != null && body != null) {
        _localNotifications.show(
          notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          // Pass data string as payload for local tap
          payload: message.data.toString(),
        );
        print("✅ Local Notification Created: $title");
      } else {
        print("⚠️ Notification rejected: Title/Body is null");
      }
    });

    // 5. Token Refresh Listener
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _updateToken(token);
    });

    // 6. Setup Interacted Message (Background/Terminated Tap)
    await setupInteractedMessage();

    // 7. Force Sync Token on Startup
    // This ensures backend has the latest token even if user is already logged in
    await syncToken();
  }

  static Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  static void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'new_order') {
      final orderIdStr = message.data['order_id'];
      if (orderIdStr != null) {
        final int? orderId = int.tryParse(orderIdStr.toString());
        if (orderId != null) {
          print("🚀 Navigating to Order Detail #$orderId");
          // Navigate to AdminOrderDetailScreen
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailScreen(orderId: orderId),
            ),
          );
        }
      }
    }
  }

  /// Called after login to ensure token is sent to backend
  static Future<void> syncToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print("FCM Token: $token");
        await _updateToken(token);
      }
    } catch (e) {
      print("Error getting FCM token: $e");
    }
  }

  static Future<void> _updateToken(String token) async {
    // Only update if user is logged in
    final authToken = StorageService.getToken();
    if (authToken != null) {
      try {
        final apiClient = ApiClient();
        apiClient.setToken(authToken);
        await apiClient.updateFcmToken(token);
        print("✅ FCM Token Synced to Backend");
      } catch (e) {
        print("❌ Failed to sync FCM token: $e");
      }
    }
  }
}
