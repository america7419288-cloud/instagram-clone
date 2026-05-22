// lib/core/services/push_notification_service.dart

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../network/dio_client.dart';

// ─────────────────────────────────────────────────────
// BACKGROUND MESSAGE HANDLER
// Must be a top-level function (not inside a class)
// ─────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in the background or terminated
  // Firebase automatically shows the notification
  // We just log it here
  debugPrint('📱 Background push: ${message.notification?.title}');
  debugPrint('   Data: ${message.data}');
}

// ─────────────────────────────────────────────────────
// LOCAL NOTIFICATIONS PLUGIN (singleton)
// ─────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ─── Android notification channel ─────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'instagram_clone_channel',  // must match AndroidManifest.xml
  'Instagram Clone',
  description: 'Instagram Clone notifications',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

// ─────────────────────────────────────────────────────
// NAVIGATION KEY (for navigating from notifications)
// ─────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Provider ─────────────────────────────────────────
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

// ─────────────────────────────────────────────────────
// PUSH NOTIFICATION SERVICE
// ─────────────────────────────────────────────────────
class PushNotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ─── Stream controller for notification taps ──────────
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  PushNotificationService(this._ref);

  // ─────────────────────────────────────────────────────
  // INITIALIZE (call once in main.dart)
  // ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    // ─── Setup background handler ──────────────────────
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // ─── Setup local notifications ─────────────────────
    await _initLocalNotifications();

    // ─── Request permission ────────────────────────────
    await requestPermission();

    // ─── Setup message handlers ────────────────────────
    _setupForegroundHandler();
    _setupMessageOpenedHandler();

    // ─── Check if app was launched from notification ───
    await _checkInitialMessage();

    // NOTE: getAndSendToken() is intentionally NOT called here.
    // auth_provider calls _registerPushToken() → getAndSendToken()
    // after login/init, ensuring the token is only sent while authenticated.

    debugPrint('✅ PushNotificationService initialized');
  }

  // ─────────────────────────────────────────────────────
  // INITIALIZE LOCAL NOTIFICATIONS
  // ─────────────────────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    // ─── Android settings ─────────────────────────────
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ─── iOS settings ─────────────────────────────────
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission:  false, // we request separately
      requestBadgePermission:  false,
      requestSoundPermission:  false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS:     iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // User tapped local notification
        final payload = details.payload;
        if (payload != null) {
          _handleNotificationData({'route': payload});
        }
      },
    );

    // ─── Create Android notification channel ──────────
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  // ─────────────────────────────────────────────────────
  // REQUEST PERMISSION
  // ─────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert:        true,
      badge:        true,
      sound:        true,
      provisional:  false,
      announcement: false,
      carPlay:      false,
      criticalAlert: false,
    );

    final granted = settings.authorizationStatus ==
        AuthorizationStatus.authorized ||
        settings.authorizationStatus ==
            AuthorizationStatus.provisional;

    debugPrint(
      granted
          ? '✅ Push permission granted'
          : '❌ Push permission denied',
    );

    return granted;
  }

  // ─────────────────────────────────────────────────────
  // GET FCM TOKEN + SEND TO SERVER
  // ─────────────────────────────────────────────────────
  Future<String?> getAndSendToken() async {
    try {
      // ─── Get token ──────────────────────────────────
      String? token;

      if (Platform.isIOS) {
        // iOS: need APNs token first
        token = await _messaging.getAPNSToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (token == null) {
          debugPrint('⚠️ Push: APNs token not ready yet (iOS simulator?)');
        }
        // Get FCM token (wraps APNs)
        token = await _messaging.getToken();
      } else {
        token = await _messaging.getToken();
      }

      if (token == null) {
        debugPrint('⚠️ Push: Could not get FCM token');
        return null;
      }

      debugPrint('📱 FCM Token: ${token.substring(0, 20)}...');

      // ─── Send to backend ────────────────────────────
      await _sendTokenToServer(token);

      // ─── Listen for token refresh ────────────────────
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('📱 FCM Token refreshed');
        _sendTokenToServer(newToken);
      });

      return token;
    } catch (e) {
      debugPrint('❌ Push getAndSendToken error: $e');
      return null;
    }
  }

  // ─── Send token to our backend ─────────────────────────
  Future<void> _sendTokenToServer(String token) async {
    try {
      final client = _ref.read(dioClientProvider);
      await client.put(
        '/users/fcm-token',
        data: {'fcmToken': token},
      );
      debugPrint('✅ FCM token sent to server');
    } catch (e) {
      debugPrint('⚠️ Push: Could not send token to server: $e');
      // Non-fatal: token will be sent on next app open
    }
  }

  // ─── Clear token from backend (on logout) ──────────────
  Future<void> clearToken() async {
    try {
      final client = _ref.read(dioClientProvider);
      await client.delete('/users/fcm-token');
      await _messaging.deleteToken();
      debugPrint('✅ FCM token cleared');
    } catch (e) {
      debugPrint('⚠️ Push: Could not clear token: $e');
    }
  }

  // ─────────────────────────────────────────────────────
  // FOREGROUND HANDLER
  // Called when app is OPEN and notification arrives
  // ─────────────────────────────────────────────────────
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Foreground push: ${message.notification?.title}');

      final notification = message.notification;
      if (notification == null) return;

      // ─── Show local notification while app is open ─────
      _showLocalNotification(
        title:   notification.title ?? 'Instagram Clone',
        body:    notification.body  ?? '',
        data:    message.data,
        id:      message.hashCode,
      );
    });
  }

  // ─────────────────────────────────────────────────────
  // BACKGROUND → OPENED HANDLER
  // Called when user taps notification while app is background
  // ─────────────────────────────────────────────────────
  void _setupMessageOpenedHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped (background): ${message.data}');
      _handleNotificationData(message.data);
    });
  }

  // ─────────────────────────────────────────────────────
  // CHECK INITIAL MESSAGE
  // Called when app was TERMINATED and user tapped notification
  // ─────────────────────────────────────────────────────
  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      debugPrint(
        '📱 App launched from notification: ${message.data}',
      );
      // Delay to let the app fully load
      await Future.delayed(const Duration(milliseconds: 1500));
      _handleNotificationData(message.data);
    }
  }

  // ─────────────────────────────────────────────────────
  // SHOW LOCAL NOTIFICATION (when app is foreground)
  // ─────────────────────────────────────────────────────
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required int id,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance:         Importance.high,
      priority:           Priority.high,
      playSound:          true,
      enableVibration:    true,
      icon:               '@mipmap/ic_launcher',
      color:              const Color(0xFF0095F6),
      styleInformation:   BigTextStyleInformation(body),
      groupKey:           'instagram_clone_group',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS:     iosDetails,
    );

    // Use route as payload for local notification
    final payload = data['route'] ?? '/notifications';

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────
  // HANDLE NOTIFICATION DATA → NAVIGATE
  // ─────────────────────────────────────────────────────
  void _handleNotificationData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    debugPrint('📱 Handling notification navigation: $data');
    _notificationTapController.add(data);
  }

  // ─────────────────────────────────────────────────────
  // NAVIGATE FROM NOTIFICATION
  // Called from UI layer with GoRouter context
  // ─────────────────────────────────────────────────────
  static void navigateFromNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final route   = data['route'] as String? ?? '/notifications';
    final postId  = data['postId'] as String?;
    final username = data['username'] as String?;
    final conversationId = data['conversationId'] as String?;

    debugPrint('📱 Navigating to: $route');

    switch (route) {
      case '/post':
        if (postId != null && postId.isNotEmpty) {
          Navigator.of(context).pushNamed('/post/$postId');
        }
        break;

      case '/profile':
        if (username != null && username.isNotEmpty) {
          Navigator.of(context).pushNamed('/profile/$username');
        }
        break;

      case '/chat':
        if (conversationId != null && conversationId.isNotEmpty) {
          Navigator.of(context).pushNamed(
            '/chat/$conversationId',
            arguments: {'username': username ?? ''},
          );
        }
        break;

      case '/notifications':
      default:
        Navigator.of(context).pushNamed('/notifications');
        break;
    }
  }

  // ─── Dispose ──────────────────────────────────────────
  void dispose() {
    _notificationTapController.close();
  }
}
