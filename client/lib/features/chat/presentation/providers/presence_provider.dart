import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../core/socket/socket_events.dart';

class PresenceState {
  final Map<String, bool> onlineUsers;
  final Map<String, DateTime> lastSeen;

  const PresenceState({
    this.onlineUsers = const {},
    this.lastSeen = const {},
  });

  PresenceState copyWith({
    Map<String, bool>? onlineUsers,
    Map<String, DateTime>? lastSeen,
  }) {
    return PresenceState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class PresenceNotifier extends Notifier<PresenceState> {
  @override
  PresenceState build() {
    final socket = ref.watch(socketServiceProvider);
    
    _listenToPresence(socket);
    
    return const PresenceState();
  }

  void _listenToPresence(socket) {
    final sub = socket.presenceStream.listen((data) {
      // 1. Handle bulk status update
      if (data.containsKey('statuses')) {
        final statuses = data['statuses'] as Map<String, dynamic>;
        final Map<String, bool> newOnlineUsers = {...state.onlineUsers};
        statuses.forEach((userId, isOnline) {
          if (isOnline == true) {
            newOnlineUsers[userId] = true;
          } else {
            newOnlineUsers.remove(userId);
          }
        });
        state = state.copyWith(onlineUsers: newOnlineUsers);
        return;
      }

      // 2. Handle online-users (initial list)
      if (data.containsKey('online_user_ids')) {
        final ids = data['online_user_ids'] as List<dynamic>;
        state = state.copyWith(
          onlineUsers: {for (var id in ids) id.toString(): true},
        );
        return;
      }

      // 3. Handle individual updates
      final userId = data[SocketKeys.userId] as String?;
      final status = data['status'] as String?;
      final lastSeenStr = data['lastSeen'] as String?;

      if (userId == null) return;

      if (status == 'online' || status == 'user-online') {
        state = state.copyWith(
          onlineUsers: {...state.onlineUsers, userId: true},
        );
      } else if (status == 'offline' || status == 'user-offline') {
        final newOnlineUsers = Map<String, bool>.from(state.onlineUsers)..remove(userId);
        final newLastSeen = Map<String, DateTime>.from(state.lastSeen);
        if (lastSeenStr != null) {
          newLastSeen[userId] = DateTime.tryParse(lastSeenStr) ?? DateTime.now();
        }
        state = state.copyWith(
          onlineUsers: newOnlineUsers,
          lastSeen: newLastSeen,
        );
      }
    });

    ref.onDispose(() => sub.cancel());
  }

  void trackUser(String userId) {
    final socket = ref.read(socketServiceProvider);
    socket.checkOnline([userId]);
  }

  void trackUsers(List<String> userIds) {
    final socket = ref.read(socketServiceProvider);
    socket.checkOnline(userIds);
  }

  bool isUserOnline(String userId) => state.onlineUsers[userId] ?? false;
  DateTime? getLastSeen(String userId) => state.lastSeen[userId];
}

final presenceProvider = NotifierProvider<PresenceNotifier, PresenceState>(PresenceNotifier.new);
