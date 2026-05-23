import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message.dart';
import '../../data/models/conversation.dart';
import '../../data/repositories/message_repository.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'chat_providers.dart';

// ─── INBOX STATE ────────────────────────────────────────────
class InboxState {
  final List<Conversation> conversations;
  final List<Conversation> requests;
  final bool isLoading;
  final String? error;

  const InboxState({
    this.conversations = const [],
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  InboxState copyWith({
    List<Conversation>? conversations,
    List<Conversation>? requests,
    bool? isLoading,
    String? error,
  }) {
    return InboxState(
      conversations: conversations ?? this.conversations,
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── INBOX NOTIFIER ─────────────────────────────────────────
// ─── INBOX NOTIFIER ─────────────────────────────────────────
class InboxNotifier extends Notifier<InboxState> {
  MessageRepository get _repository => ref.read(messageRepositoryProvider);
  StreamSubscription? _socketSub;
  StreamSubscription? _inboxSub;

  @override
  InboxState build() {
    _init();
    return const InboxState();
  }

  Future<void> _init() async {
    await ref.read(chatInitProvider.future);
    loadConversations();
    _listenToSocket();
  }

  void _listenToSocket() {
    _socketSub = _repository.onMessageEvent.listen((data) {
      // Refresh conversations on any message event
      loadConversations();
    });

    _inboxSub = ref.read(socketServiceProvider).inboxStream.listen((data) {
      loadConversations();
    });

    ref.onDispose(() {
      _socketSub?.cancel();
      _inboxSub?.cancel();
    });
  }

  Future<void> refresh() => loadConversations();

  Future<Conversation> createConversation(String participantId) async {
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId != null && participantId == currentUserId) {
      throw Exception('Cannot create a conversation with yourself.');
    }

    final conversation = await _repository.createConversation(participantId);
    await loadConversations();
    return conversation;
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repository.getConversations(),
        _repository.getMessageRequests(),
      ]);
      state = state.copyWith(
        conversations: results[0],
        requests: results[1],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> acceptRequest(String conversationId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.acceptRequest(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectRequest(String conversationId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.rejectRequest(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadUnreadCount() async {
    await loadConversations();
  }

  Future<void> deleteConversation(String conversationId) async {
    // Optimistic UI update
    state = state.copyWith(
      conversations: state.conversations.where((c) => c.id != conversationId).toList(),
      requests: state.requests.where((c) => c.id != conversationId).toList(),
    );
    try {
      await _repository.deleteConversation(conversationId);
    } catch (e) {
      loadConversations();
    }
  }

  Future<void> markAsUnread(String conversationId) async {
    try {
      await _repository.markAsUnread(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _repository.markAsRead(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> muteConversation(String conversationId, String duration) async {
    try {
      await _repository.muteConversation(conversationId, duration);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> unmuteConversation(String conversationId) async {
    try {
      await _repository.unmuteConversation(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ─── CHAT STATE ─────────────────────────────────────────────
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = true,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

// ─── CHAT NOTIFIER ──────────────────────────────────────────
class ChatNotifier extends Notifier<ChatState> {
  late String conversationId;
  MessageRepository get _repository => ref.read(messageRepositoryProvider);
  StreamSubscription? _socketSub;
  StreamSubscription? _connSub;

  @override
  ChatState build() {
    _init();
    return const ChatState();
  }

  Future<void> _init() async {
    await ref.read(chatInitProvider.future);

    _repository.joinConversation(conversationId);
    loadMessages();
    _listenToSocket();
    unawaited(_repository.markAsRead(conversationId));

    // Listen for reconnection to re-join room
    _connSub = ref.read(socketServiceProvider).connectionStream.listen((
      connected,
    ) {
      if (connected) {
        _repository.joinConversation(conversationId);
      }
    });

    ref.onDispose(() {
      _repository.leaveConversation(conversationId);
      _socketSub?.cancel();
      _connSub?.cancel();
    });
  }

  void _listenToSocket() {
    _socketSub?.cancel();
    _socketSub = _repository.onMessageEvent.listen((data) {
      final String? msgConvId =
          data['conversation_id'] ?? (data['message']?['conversation_id']);
      if (msgConvId != conversationId) return;

      final String? type = data['type'];

      if (type == 'delete') {
        final messageId = data['message_id'];
        unawaited(_repository.deleteLocalMessage(messageId));
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != messageId).toList(),
        );
      } else if (type == 'edit') {
        final msgData = data['message'];
        if (msgData != null) {
          final message = Message.fromJson(msgData);
          state = state.copyWith(
            messages: state.messages.map((m) {
              return m.id == message.id ? message : m;
            }).toList(),
          );
          unawaited(_repository.saveMessage(message));
        }
      } else if (type == 'reaction') {
        final messageId = data['message_id'];
        final emoji = data['emoji'];

        state = state.copyWith(
          messages: state.messages.map((m) {
            if (m.id == messageId) {
              final updatedReactions = Map<String, int>.from(m.reactions ?? {});
              updatedReactions[emoji] = (updatedReactions[emoji] ?? 0) + 1;
              return m.copyWith(reactions: updatedReactions);
            }
            return m;
          }).toList(),
        );
      } else {
        final msgData = data['message'] ?? data;
        final message = Message.fromJson(msgData);
        final incomingTempId = message.tempId;
        unawaited(_repository.saveMessage(message));

        final existingIndex = state.messages.indexWhere(
          (m) =>
              m.id == message.id ||
              (incomingTempId != null &&
                  (m.id == incomingTempId || m.tempId == incomingTempId)),
        );

        if (existingIndex == -1) {
          state = state.copyWith(messages: [message, ...state.messages]);
        } else {
          final updatedMessages = List<Message>.from(state.messages);
          updatedMessages[existingIndex] = message;
          state = state.copyWith(messages: updatedMessages);
        }
        unawaited(_repository.markAsRead(conversationId));
      }
    });
  }

  Future<void> markAsRead() async {
    await _repository.markAsRead(conversationId);
  }

  Future<void> loadMessages() async {
    final cachedMessages = _repository.getCachedMessages(conversationId);
    if (cachedMessages.isNotEmpty) {
      state = state.copyWith(
        messages: cachedMessages,
        isLoading: false,
        hasMore: cachedMessages.length >= 20,
      );
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final messages = await _repository.getMessages(conversationId);
      if (messages.isEmpty && cachedMessages.isNotEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.messages.isEmpty) return;

    try {
      final oldestMessage = state.messages.last;
      final moreMessages = await _repository.getMessages(
        conversationId,
        before: oldestMessage.createdAt.toIso8601String(),
      );

      if (moreMessages.isEmpty) {
        state = state.copyWith(hasMore: false);
      } else {
        state = state.copyWith(
          messages: [...state.messages, ...moreMessages],
          hasMore: moreMessages.length >= 20,
        );
      }
    } catch (e) {
      // Log error
    }
  }

  Future<void> sendMessage(
    String content, {
    String? replyToId,
    String messageType = 'text',
    String? mediaPath,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    // Build an optimistic message for instant UI feedback
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimistic = Message(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUser.id,
      content: content,
      messageType: messageType,
      createdAt: DateTime.now(),
      isSending: true,
      tempId: tempId,
      replyToId: replyToId,
      localPath: mediaPath,
      sender: null, // will be filled from server
    );

    // Show immediately
    state = state.copyWith(messages: [optimistic, ...state.messages]);

    try {
      final message = await _repository.sendMessage(
        conversationId,
        content,
        currentUser.id,
        replyToId: replyToId,
        messageType: messageType,
        mediaPath: mediaPath,
        tempId: tempId,
      );

      // Replace optimistic with confirmed server message (match by tempId too,
      // in case the socket already swapped it from tempId→realId)
      final updatedMessages = state.messages.map((m) {
        if (m.id == tempId || (m.tempId != null && m.tempId == tempId)) {
          return message;
        }
        return m;
      }).toList();

      // Deduplicate by id — the socket may have already inserted the real
      // message before the HTTP response arrived, causing a second copy.
      final seen = <String>{};
      final deduped = updatedMessages.where((m) => seen.add(m.id)).toList();

      state = state.copyWith(messages: deduped);
    } catch (e) {
      // Mark as failed
      state = state.copyWith(
        messages: state.messages
            .map(
              (m) => m.id == tempId
                  ? m.copyWith(isSending: false, hasError: true)
                  : m,
            )
            .toList(),
        error: e.toString(),
      );
    }
  }

  Future<void> sendMediaMessage(String path, String type) async {
    await sendMessage('', messageType: type, mediaPath: path);
  }

  Future<void> sendLike() async {
    await sendMessage('❤️', messageType: 'like');
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _repository.addReaction(conversationId, messageId, emoji);
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == messageId) {
            final updatedReactions = Map<String, int>.from(m.reactions ?? {});
            updatedReactions[emoji] = (updatedReactions[emoji] ?? 0) + 1;
            return m.copyWith(reactions: updatedReactions);
          }
          return m;
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(conversationId, messageId);
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> editMessage(String messageId, String content) async {
    try {
      final message = await _repository.editMessage(conversationId, messageId, content);
      state = state.copyWith(
        messages: state.messages.map((m) {
          return m.id == messageId ? message : m;
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setDisappearingMessages(int? durationSeconds) async {
    try {
      await _repository.setDisappearingMessages(conversationId, durationSeconds);
      await ref.read(inboxProvider.notifier).loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final inboxProvider = NotifierProvider<InboxNotifier, InboxState>(
  InboxNotifier.new,
);

final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>(
  (id) => ChatNotifier()..conversationId = id,
);

final totalUnreadCountProvider = Provider<int>((ref) {
  final inboxState = ref.watch(inboxProvider);
  return inboxState.conversations.fold(
    0,
    (sum, conv) => sum + conv.unreadCount,
  );
});
