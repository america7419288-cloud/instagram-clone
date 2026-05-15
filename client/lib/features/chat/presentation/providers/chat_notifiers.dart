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
  final bool isLoading;
  final String? error;

  const InboxState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  InboxState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return InboxState(
      conversations: conversations ?? this.conversations,
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
    final conversation = await _repository.createConversation(participantId);
    await loadConversations();
    return conversation;
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    try {
      final conversations = await _repository.getConversations();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadUnreadCount() async {
    await loadConversations();
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
    _repository.markAsRead(conversationId);
    
    ref.onDispose(() {
      _repository.leaveConversation(conversationId);
      _socketSub?.cancel();
    });
  }

  void _listenToSocket() {
    _socketSub = _repository.onMessageEvent.listen((data) {
      final String? msgConvId = data['conversation_id'] ?? (data['message']?['conversation_id']);
      if (msgConvId != conversationId) return;

      final String? type = data['type'];
      
      if (type == 'delete') {
        final messageId = data['message_id'];
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != messageId).toList(),
        );
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
        // New message — guard against duplicates from our own sends.
        // Check both real ID and tempId: the optimistic message still has
        // id = tempId (the local timestamp string) at this point, so matching
        // only on message.id misses it and causes a double-render.
        final msgData = data['message'] ?? data;
        final message = Message.fromJson(msgData);
        final incomingTempId = message.tempId;
        final alreadyExists = state.messages.any((m) =>
            m.id == message.id ||
            (incomingTempId != null &&
                (m.id == incomingTempId || m.tempId == incomingTempId)));
        if (!alreadyExists) {
          state = state.copyWith(messages: [message, ...state.messages]);
        } else if (incomingTempId != null) {
          // Replace the optimistic entry with the confirmed server message
          // (in case the API response hasn't arrived yet but the socket has)
          state = state.copyWith(
            messages: state.messages.map((m) =>
              (m.id == incomingTempId || m.tempId == incomingTempId)
                  ? message
                  : m,
            ).toList(),
          );
        }
        _repository.markAsRead(conversationId);
      }
    });
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _repository.getMessages(conversationId);
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

  Future<void> sendMessage(String content, {
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
      final deduped = updatedMessages
          .where((m) => seen.add(m.id))
          .toList();

      state = state.copyWith(messages: deduped);
    } catch (e) {
      // Mark as failed
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == tempId ? m.copyWith(isSending: false, hasError: true) : m)
            .toList(),
        error: e.toString(),
      );
    }
  }

  Future<void> sendMediaMessage(String path, String type) async {
    await sendMessage('', messageType: type, mediaPath: path);
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
}

// ─── PROVIDERS ──────────────────────────────────────────────
final inboxProvider = NotifierProvider<InboxNotifier, InboxState>(InboxNotifier.new);

final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>(
  (conversationId) => ChatNotifier()..conversationId = conversationId,
);

final totalUnreadCountProvider = Provider<int>((ref) {
  final inboxState = ref.watch(inboxProvider);
  return inboxState.conversations.fold(0, (sum, conv) => sum + conv.unreadCount);
});
