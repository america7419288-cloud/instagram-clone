// lib/features/notifications/presentation/providers/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/repositories/notification_service.dart';

// ─── NOTIFICATION STATE ─────────────────────────────────────
class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  // Group notifications by time period
  List<NotificationGroup> get groupedNotifications {
    if (notifications.isEmpty) return [];

    final now = DateTime.now();
    final groups = <NotificationGroup>[];

    // This Week (last 7 days)
    final thisWeek = notifications.where((n) {
      if (n.createdAt == null) return false;
      return now.difference(n.createdAt!).inDays < 7;
    }).toList();

    // This Month (7-30 days)
    final thisMonth = notifications.where((n) {
      if (n.createdAt == null) return false;
      final diff = now.difference(n.createdAt!).inDays;
      return diff >= 7 && diff < 30;
    }).toList();

    // Earlier (30+ days)
    final earlier = notifications.where((n) {
      if (n.createdAt == null) return false;
      return now.difference(n.createdAt!).inDays >= 30;
    }).toList();

    if (thisWeek.isNotEmpty) {
      groups.add(NotificationGroup(
        title: 'This Week',
        notifications: thisWeek,
      ));
    }

    if (thisMonth.isNotEmpty) {
      groups.add(NotificationGroup(
        title: 'This Month',
        notifications: thisMonth,
      ));
    }

    if (earlier.isNotEmpty) {
      groups.add(NotificationGroup(
        title: 'Earlier',
        notifications: earlier,
      ));
    }

    return groups;
  }
}

// ─── NOTIFICATION NOTIFIER ──────────────────────────────────
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;

  NotificationNotifier(this._service)
      : super(const NotificationState()) {
    loadNotifications();
    loadUnreadCount();
  }

  // ─── LOAD NOTIFICATIONS ─────────────────────────────────
  Future<void> loadNotifications() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      currentPage: 1,
    );

    try {
      final result = await _service.getNotifications(page: 1);
      final notifications =
          result['notifications'] as List<NotificationModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD MORE ──────────────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.getNotifications(
        page: nextPage,
      );
      final newNotifications =
          result['notifications'] as List<NotificationModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        notifications: [
          ...state.notifications,
          ...newNotifications,
        ],
        isLoadingMore: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─── LOAD UNREAD COUNT ──────────────────────────────────
  Future<void> loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      // Silent fail - badge just shows 0
    }
  }

  // ─── MARK ONE AS READ ───────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    // Update locally first
    final updated = state.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return n.markAsRead();
      }
      return n;
    }).toList();

    final wasUnread = state.notifications
        .any((n) => n.id == notificationId && !n.isRead);

    state = state.copyWith(
      notifications: updated,
      unreadCount:
          wasUnread && state.unreadCount > 0
              ? state.unreadCount - 1
              : state.unreadCount,
    );

    // Then call API (silent)
    try {
      await _service.markAsRead(notificationId);
    } catch (e) {
      // Ignore error for marking as read
    }
  }

  // ─── MARK ALL AS READ ───────────────────────────────────
  Future<void> markAllAsRead() async {
    // Mark all locally
    final updated =
        state.notifications.map((n) => n.markAsRead()).toList();

    state = state.copyWith(
      notifications: updated,
      unreadCount: 0,
    );

    try {
      await _service.markAllAsRead();
    } catch (e) {
      // Silent - user sees it worked
    }
  }

  // ─── DELETE NOTIFICATION ────────────────────────────────
  Future<void> deleteNotification(String notificationId) async {
    // Check if it was unread
    final wasUnread = state.notifications
        .any((n) => n.id == notificationId && !n.isRead);

    // Remove from local list
    final updated = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    state = state.copyWith(
      notifications: updated,
      unreadCount: wasUnread && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount,
    );

    try {
      await _service.deleteNotification(notificationId);
    } catch (e) {
      // Re-add on failure
      await loadNotifications();
    }
  }

  // ─── DELETE ALL ─────────────────────────────────────────
  Future<void> deleteAllNotifications() async {
    state = state.copyWith(
      notifications: [],
      unreadCount: 0,
    );

    try {
      await _service.deleteAllNotifications();
    } catch (e) {
      await loadNotifications();
    }
  }

  // ─── REFRESH ────────────────────────────────────────────
  Future<void> refresh() async {
    await Future.wait([
      loadNotifications(),
      loadUnreadCount(),
    ]);
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final notificationServiceProvider =
    Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationProvider = StateNotifierProvider<
    NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(
    ref.watch(notificationServiceProvider),
  );
});

// Convenience: just the unread count (for badge)
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
