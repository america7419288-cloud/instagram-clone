import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../core/socket/socket_events.dart';
import '../../data/repositories/message_repository.dart';
import 'chat_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TypingState {
  final Set<String> typingUserIds;
  final bool amITyping;

  const TypingState({
    this.typingUserIds = const {},
    this.amITyping = false,
  });

  bool get isTyping => typingUserIds.isNotEmpty;

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
  late String conversationId;
  final Map<String, Timer> _typingTimers = {};
  StreamSubscription? _typingSub;
  Timer? _stopTypingTimer;

  @override
  TypingState build() {
    final socket = ref.watch(socketServiceProvider);

    _listenToTyping(socket);

    ref.onDispose(() {
      for (final t in _typingTimers.values) {
        t.cancel();
      }
      _typingSub?.cancel();
      _stopTypingTimer?.cancel();
    });

    return const TypingState();
  }

  void _listenToTyping(socket) {
    _typingSub?.cancel();
    _typingSub = socket.typingStream.listen((data) {
      if (data[SocketKeys.conversationId] != conversationId) return;

      final userId = data[SocketKeys.userId] as String?;
      final isTyping = data[SocketKeys.isTyping] as bool? ?? true;

      if (userId == null) return;

      if (isTyping) {
        // Don't show myself as typing
        final currentUserId = ref.read(authProvider).user?.id;
        if (userId == currentUserId) return;

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
  }

  void onTextChanged(String text) {
    if (text.isEmpty) {
      if (state.amITyping) {
        state = state.copyWith(amITyping: false);
        ref.read(messageRepositoryProvider).setTyping(conversationId, false);
      }
      _stopTypingTimer?.cancel();
      return;
    }

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
  (id) => TypingNotifier()..conversationId = id,
);
