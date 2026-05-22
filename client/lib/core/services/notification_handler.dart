import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/in_app_notification_banner.dart';
import 'push_notification_service.dart';

class NotificationHandler extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationHandler({super.key, required this.child});

  @override
  ConsumerState<NotificationHandler> createState() =>
      _NotificationHandlerState();
}

class _NotificationHandlerState
    extends ConsumerState<NotificationHandler> {
  @override
  void initState() {
    super.initState();
    _initPushService();
  }

  Future<void> _initPushService() async {
    try {
      final pushService = ref.read(pushNotificationServiceProvider);

      // ─── Initialize (channel + permission + handlers) ──
      await pushService.initialize();

      // ─── Listen for notification taps → navigate ───────
      pushService.onNotificationTap.listen((data) {
        if (mounted) _handleNavigation(data);
      });

      // ─── Show in-app banner for foreground messages ─────
      // push_notification_service also shows a system notification;
      // here we additionally show the custom in-app banner.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        final notification = message.notification;
        if (notification == null) return;

        InAppNotificationBanner.show(
          context,
          title:    notification.title ?? 'Instagram Clone',
          body:     notification.body  ?? '',
          onTap:    () => _handleNavigation(message.data),
        );
      });

    } catch (e) {
      debugPrint('⚠️ Push service init error: $e');
    }
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final route          = data['route'] as String? ?? '/notifications';
    final postId         = data['postId'] as String?;
    final username       = data['username'] as String?;
    final conversationId = data['conversationId'] as String?;

    debugPrint('📱 Navigate from notification: route=$route');

    try {
      switch (route) {
        case '/post':
          if (postId != null && postId.isNotEmpty) {
            context.push('/post/$postId');
          } else {
            context.go('/notifications');
          }
          break;

        case '/profile':
          if (username != null && username.isNotEmpty) {
            context.push('/profile/$username');
          } else {
            context.go('/notifications');
          }
          break;

        case '/chat':
          if (conversationId != null && conversationId.isNotEmpty) {
            context.push(
              '/chat/$conversationId',
              extra: {
                'username': username ?? '',
                'userId':   '',
              },
            );
          } else {
            context.go('/messages');
          }
          break;

        default:
          context.go('/notifications');
          break;
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
