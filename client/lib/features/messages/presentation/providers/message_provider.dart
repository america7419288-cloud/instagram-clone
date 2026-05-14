// lib/features/messages/presentation/providers/message_provider.dart
// COMPLETE UPDATED FILE with Socket.io integration and modern Notifier API

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_service.dart';
import '../../../../core/socket/socket_provider.dart';

// ─── INBOX STATE ────────────────────────────────────────────
class InboxState {
  final List<ConversationModel> conversations;
  final bool isLoading;
  final String? errorMessage;
  final int dmUnreadCount;

  const InboxState({
    this.conversations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.dmUnreadCount = 0,
  });

  InboxState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    String? errorMessage,
    int? dmUnreadCount,
  }) {
    return InboxState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      dmUnreadCount: dmUnreadCount ?? this.dmUnreadCount,
    );
  }
}

// ─── INBOX NOTIFIER ─────────────────────────────────────────
class InboxNotifier extends Notifier<InboxState> {
  MessageService get _service => ref.read(messageServiceProvider);
  Timer? _pollingTimer;

  @override
  InboxState build() {
    // 1. Initial Loads
    Future.microtask(() {
      loadInbox();
      loadUnreadCount();
      _registerSocketHandlers();
    });

    // 2. Polling Fallback
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadUnreadCount();
    });

    // 3. Cleanup
    ref.onDispose(() {
      _pollingTimer?.cancel();
      ref.read(socketProvider.notifier).unregisterInboxHandler('inbox');
    });

    return const InboxState();
  }

  // ─── REGISTER SOCKET HANDLERS ─────────────────────────────
  void _registerSocketHandlers() {
    ref.read(socketProvider.notifier).registerInboxHandler('inbox', (data) {
      // 1. Update unread count
      loadUnreadCount();

      // 2. Update specific conversation
      final conversationId =
          data['conversation_id'] as String? ??
          data['message']?['conversation_id'] as String? ??
          '';

      final lastMessage =
          data['last_message'] as String? ??
          data['message']?['content'] as String? ??
          '';

      if (conversationId.isNotEmpty) {
        updateConversationLastMessage(conversationId, lastMessage);
      } else {
        // Full refresh if no ID
        loadInbox();
      }
    });
  }

  Future<void> loadInbox() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final conversations = await _service.getInbox();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(dmUnreadCount: count);
    } catch (e) {
      // Silent fail
    }
  }

  void updateConversationLastMessage(
    String conversationId,
    String lastMessage,
  ) {
    final updated = state.conversations.map((c) {
      if (c.id == conversationId) {
        return ConversationModel(
          id: c.id,
          isGroup: c.isGroup,
          name: c.name,
          avatarUrl: c.avatarUrl,
          lastMessage: lastMessage,
          lastMessageAt: DateTime.now(),
          unreadCount: c.unreadCount,
          otherUser: c.otherUser,
          participants: c.participants,
          createdAt: c.createdAt,
        );
      }
      return c;
    }).toList();

    updated.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });

    state = state.copyWith(conversations: updated);
  }

  void addConversation(ConversationModel conversation) {
    final exists = state.conversations.any((c) => c.id == conversation.id);
    if (!exists) {
      state = state.copyWith(
        conversations: [conversation, ...state.conversations],
      );
    }
  }

  Future<ConversationModel?> createConversation(String userId) async {
    try {
      final conversation = await _service.createOrGetConversation(userId);
      addConversation(conversation);
      return conversation;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<void> refresh() => loadInbox();
}

// ─── CHAT STATE ─────────────────────────────────────────────
class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSending;
  final bool hasMore;
  final int currentPage;
  final String? errorMessage;
  final MessageModel? replyingTo;
  // Typing indicator
  final bool isOtherUserTyping;
  final String? typingUserId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.errorMessage,
    this.replyingTo,
    this.isOtherUserTyping = false,
    this.typingUserId,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSending,
    bool? hasMore,
    int? currentPage,
    String? errorMessage,
    MessageModel? replyingTo,
    bool clearReplyingTo = false,
    bool? isOtherUserTyping,
    String? typingUserId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
      typingUserId: typingUserId ?? this.typingUserId,
    );
  }
}

// ─── CHAT NOTIFIER (per conversation) ───────────────────────
class ChatNotifier extends Notifier<ChatState> {
  MessageService get _service => ref.read(messageServiceProvider);
  late String conversationId;

  // Typing debounce
  DateTime? _lastTypingEmit;
  static const _typingDebounce = Duration(seconds: 2);

  @override
  ChatState build() {

    Future.microtask(() {
      loadMessages();
      _joinSocketRoom();
      _registerSocketHandlers();
      _service.markAsRead(conversationId);
    });

    ref.onDispose(() {
      _leaveSocketRoom();
      ref.read(socketProvider.notifier).unregisterMessageHandler(conversationId);
    });

    return const ChatState();
  }

  // ─── JOIN SOCKET ROOM ─────────────────────────────────────
  void _joinSocketRoom() {
    ref.read(socketProvider.notifier).joinRoom(conversationId);
  }

  // ─── LEAVE SOCKET ROOM ───────────────────────────────────
  void _leaveSocketRoom() {
    ref.read(socketProvider.notifier).leaveRoom(conversationId);
  }

  // ─── REGISTER SOCKET HANDLERS ─────────────────────────────
  void _registerSocketHandlers() {
    // Handle new messages for THIS conversation
    ref.read(socketProvider.notifier).registerMessageHandler(conversationId, (
      data,
    ) {
      final msgData = data['message'] as Map<String, dynamic>?;
      if (msgData == null) return;

      final msgConvId = msgData['conversation_id'] as String? ?? '';
      if (msgConvId != conversationId) return;

      // Parse the message
      final message = MessageModel.fromJson(msgData);

      // Add to state (avoid duplicates)
      addNewMessage(message);

      // Mark as read since we're viewing this conversation
      ref.read(socketProvider.notifier).emitMessageRead(conversationId);
    });

    // Watch for typing changes in this conversation
    ref.listen(socketProvider, (previous, next) {
      final typingUserId = next.getTypingUser(conversationId);
      final isTyping = typingUserId != null;

      state = state.copyWith(
        isOtherUserTyping: isTyping,
        typingUserId: typingUserId,
      );
    });
  }

  // ─── LOAD MESSAGES ──────────────────────────────────────
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.getMessages(
        conversationId: conversationId,
        page: 1,
      );

      final messages = result['messages'] as List<MessageModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        messages: messages,
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
      final result = await _service.getMessages(
        conversationId: conversationId,
        page: nextPage,
      );

      final newMessages = result['messages'] as List<MessageModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        messages: [...state.messages, ...newMessages],
        isLoadingMore: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─── SEND MESSAGE ────────────────────────────────────────
  Future<bool> sendMessage(String content) async {
    if (state.isSending || content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    // Stop typing when sending
    ref.read(socketProvider.notifier).emitStopTyping(conversationId);

    try {
      final message = await _service.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
        replyToMessageId: state.replyingTo?.id,
      );

      addNewMessage(message);
      state = state.copyWith(isSending: false, clearReplyingTo: true);

      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── UNSEND MESSAGE ──────────────────────────────────────
  Future<void> unsendMessage(String messageId) async {
    try {
      await _service.deleteMessage(messageId);

      final updated = state.messages.map((m) {
        if (m.id == messageId) return m.copyWith(isDeleted: true);
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── EMIT TYPING (with debounce) ─────────────────────────
  void onTextChanged(String text) {
    if (text.isEmpty) {
      ref.read(socketProvider.notifier).emitStopTyping(conversationId);
      return;
    }

    final now = DateTime.now();
    if (_lastTypingEmit == null ||
        now.difference(_lastTypingEmit!) > _typingDebounce) {
      _lastTypingEmit = now;
      ref.read(socketProvider.notifier).emitTyping(conversationId);
    }
  }

  // ─── ADD NEW MESSAGE (from socket) ───────────────────────
  void addNewMessage(MessageModel message) {
    final exists = state.messages.any((m) => m.id == message.id);
    if (!exists) {
      state = state.copyWith(messages: [message, ...state.messages]);
    }
  }

  // ─── SET REPLYING TO ─────────────────────────────────────
  void setReplyingTo(MessageModel? message) {
    state = state.copyWith(
      replyingTo: message,
      clearReplyingTo: message == null,
    );
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService();
});

final inboxProvider = NotifierProvider<InboxNotifier, InboxState>(InboxNotifier.new);

final dmUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(inboxProvider).dmUnreadCount;
});

final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, String>(
  (conversationId) => ChatNotifier()..conversationId = conversationId,
);
