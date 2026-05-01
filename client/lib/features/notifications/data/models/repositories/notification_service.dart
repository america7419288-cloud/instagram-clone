// lib/features/notifications/data/repositories/notification_service.dart

import 'package:dio/dio.dart';
import '../../../../../core/network/dio_client.dart';
import '../notification_model.dart';

class NotificationService {
  final DioClient _dioClient = DioClient();

  // ─── GET NOTIFICATIONS ───────────────────────────────────
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final response = await _dioClient.get(
        '/notifications/',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (type != null) 'type': type,
        },
      );

      final data = response.data;
      final notifications =
          (data['data'] as List<dynamic>? ?? [])
              .map((n) => NotificationModel.fromJson(
                    n as Map<String, dynamic>,
                  ))
              .toList();

      return {
        'notifications': notifications,
        'pagination': data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET UNREAD COUNT ────────────────────────────────────
  Future<int> getUnreadCount() async {
    try {
      final response = await _dioClient.get(
        '/notifications/unread-count',
      );
      return response.data['data']['unread_count'] as int? ?? 0;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── MARK ONE AS READ ────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dioClient.put(
        '/notifications/$notificationId/read',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── MARK ALL AS READ ────────────────────────────────────
  Future<void> markAllAsRead() async {
    try {
      await _dioClient.put('/notifications/read-all');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── DELETE ONE ──────────────────────────────────────────
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _dioClient.delete('/notifications/$notificationId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── DELETE ALL ──────────────────────────────────────────
  Future<void> deleteAllNotifications() async {
    try {
      await _dioClient.delete('/notifications/');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}
