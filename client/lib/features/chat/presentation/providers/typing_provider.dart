import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../core/socket/socket_events.dart';
import '../../data/repositories/message_repository.dart';
import 'chat_providers.dart';

class TypingState {
  final Set<String> typingUserIds;
  final bool amITyping;

  const TypingState({
    this.typingUserIds = const {},
    this.amITyping = false,
  });

  TypingState copyWith({
    Set<String>? typingUserIds,
    bool? amITyping,
  }) {
    return TypingState(
      typingUserIds: typingUserIds ?? this.typingUserIds,
      amITyping: amITyping ?? this.amITyping,
    );
  }
}

// Riverpod 3.x: FamilyNotifier removed — use Notifier with constructor injection
class TypingNotifier extends Notifier<TypingState> {
  final String conversationId;
  final Map<String, Timer> _typingTimers = {};
  Timer? _stopTypingTimer;

  TypingNotifier(this.conversationId);

  @override
  TypingState build() {
    final socket = ref.watch(socketServiceProvider);

    _listenToTyping(socket);

    ref.onDispose(() {
      for (final t in _typingTimers.values) {
        t.cancel();
      }
      _stopTypingTimer?.cancel();
    });

    return const TypingState();
  }

  void _listenToTyping(socket) {
    final sub = socket.typingStream.listen((data) {
      if (data[SocketKeys.conversationId] != conversationId) return;

      final userId = data[SocketKeys.userId] as String?;
      final isTyping = data['isTyping'] as bool? ?? true;

      if (userId == null) return;

      if (isTyping) {
        final newTypingUsers = Set<String>.from(state.typingUserIds)..add(userId);
        state = state.copyWith(typingUserIds: newTypingUsers);

        _typingTimers[userId]?.cancel();
        _typingTimers[userId] = Timer(const Duration(seconds: 6), () {
          final updatedUsers = Set<String>.from(state.typingUserIds)..remove(userId);
          state = state.copyWith(typingUserIds: updatedUsers);
        });
      } else {
        final newTypingUsers = Set<String>.from(state.typingUserIds)..remove(userId);
        state = state.copyWith(typingUserIds: newTypingUsers);
        _typingTimers[userId]?.cancel();
      }
    });

    ref.onDispose(() => sub.cancel());
  }

  void onTyping() {
    if (!state.amITyping) {
      state = state.copyWith(amITyping: true);
      ref.read(messageRepositoryProvider).setTyping(conversationId, true);
    }

    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(amITyping: false);
      ref.read(messageRepositoryProvider).setTyping(conversationId, false);
    });
  }
}

final typingProvider = NotifierProvider.family<TypingNotifier, TypingState, String>(
  (conversationId) => TypingNotifier(conversationId),
);
