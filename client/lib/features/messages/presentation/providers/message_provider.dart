// lib/features/messages/presentation/providers/message_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_service.dart';

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
class InboxNotifier extends StateNotifier<InboxState> {
  final MessageService _service;

  InboxNotifier(this._service) : super(const InboxState()) {
    loadInbox();
    loadUnreadCount();
  }

  Future<void> loadInbox() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final conversations = await _service.getInbox();
      if (!mounted) return;
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (mounted) {
        state = state.copyWith(dmUnreadCount: count);
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Update last message preview in inbox after sending
  void updateConversationLastMessage(
    String conversationId,
    String lastMessage,
  ) {
    if (!mounted) return;
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

    // Sort by last message time
    updated.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });

    state = state.copyWith(conversations: updated);
  }

  // Add new conversation to top of inbox
  void addConversation(ConversationModel conversation) {
    if (!mounted) return;
    final exists = state.conversations.any(
      (c) => c.id == conversation.id,
    );
    if (!exists) {
      state = state.copyWith(
        conversations: [conversation, ...state.conversations],
      );
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
  final MessageModel? replyingTo; // Message being replied to

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.errorMessage,
    this.replyingTo,
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
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage,
      replyingTo:
          clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
    );
  }
}

// ─── CHAT NOTIFIER (per conversation) ───────────────────────
class ChatNotifier extends StateNotifier<ChatState> {
  final MessageService _service;
  final String conversationId;

  ChatNotifier(this._service, this.conversationId)
      : super(const ChatState()) {
    loadMessages();
    // Mark as read when opening chat
    _service.markAsRead(conversationId);
  }

  // ─── LOAD MESSAGES ──────────────────────────────────────
  Future<void> loadMessages() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.getMessages(
        conversationId: conversationId,
        page: 1,
      );
      if (!mounted) return;

      final messages = result['messages'] as List<MessageModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: 1,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD MORE (older messages) ──────────────────────────
  Future<void> loadMore() async {
    if (!mounted || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.getMessages(
        conversationId: conversationId,
        page: nextPage,
      );
      if (!mounted) return;

      final newMessages = result['messages'] as List<MessageModel>;
      final pagination = result['pagination'];

      // Append older messages at the END (since list is newest first)
      state = state.copyWith(
        messages: [...state.messages, ...newMessages],
        isLoadingMore: false,
        hasMore: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─── SEND MESSAGE ────────────────────────────────────────
  Future<bool> sendMessage(String content) async {
    if (!mounted || content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _service.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
        replyToMessageId: state.replyingTo?.id,
      );
      if (!mounted) return false;

      // Add new message to TOP (newest first)
      state = state.copyWith(
        messages: [message, ...state.messages],
        isSending: false,
        clearReplyingTo: true,
      );

      return true;
    } catch (e) {
      if (!mounted) return false;
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
      if (!mounted) return;

      // Mark as deleted locally
      final updated = state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(isDeleted: true);
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updated);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── SET REPLYING TO ─────────────────────────────────────
  void setReplyingTo(MessageModel? message) {
    if (!mounted) return;
    state = state.copyWith(
      replyingTo: message,
      clearReplyingTo: message == null,
    );
  }

  // ─── ADD NEW MESSAGE (from socket - Day 24) ──────────────
  void addNewMessage(MessageModel message) {
    if (!mounted) return;
    // Check not duplicate
    final exists = state.messages.any((m) => m.id == message.id);
    if (!exists) {
      state = state.copyWith(
        messages: [message, ...state.messages],
      );
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService();
});

// Inbox provider
final inboxProvider =
    StateNotifierProvider<InboxNotifier, InboxState>((ref) {
  return InboxNotifier(ref.watch(messageServiceProvider));
});

// DM unread count provider
final dmUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(inboxProvider).dmUnreadCount;
});

// Per-conversation chat provider (family)
final chatProvider = StateNotifierProvider.family<
    ChatNotifier, ChatState, String>(
  (ref, conversationId) => ChatNotifier(
    ref.watch(messageServiceProvider),
    conversationId,
  ),
);