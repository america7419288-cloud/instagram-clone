// lib/features/messages/presentation/providers/message_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class InboxNotifier extends Notifier<InboxState> {
  MessageService get _service => ref.read(messageServiceProvider);

  @override
  InboxState build() {
    // Start loading data immediately
    Future.microtask(() {
      loadInbox();
      loadUnreadCount();
    });
    return const InboxState();
  }

  Future<void> loadInbox() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final conversations = await _service.getInbox();
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
      );
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

  // Update last message preview in inbox after sending
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

    state = state.copyWith(conversations: updated);
  }

  void addConversation(ConversationModel conv) {
    // Check if already exists
    final exists = state.conversations.any((c) => c.id == conv.id);
    if (!exists) {
      state = state.copyWith(
        conversations: [conv, ...state.conversations],
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
      return null;
    }
  }

  Future<void> refresh() async {
    await loadInbox();
    await loadUnreadCount();
  }
}

// ─── CHAT STATE ─────────────────────────────────────────────
class ChatState {
  final String conversationId;
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSending;
  final bool hasMore;
  final int page;
  final String? errorMessage;
  final MessageModel? replyingTo;

  const ChatState({
    required this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.hasMore = true,
    this.page = 1,
    this.errorMessage,
    this.replyingTo,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSending,
    bool? hasMore,
    int? page,
    String? errorMessage,
    MessageModel? replyingTo,
    bool clearReplyingTo = false,
  }) {
    return ChatState(
      conversationId: conversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
    );
  }
}

// ─── CHAT NOTIFIER ──────────────────────────────────────────
class ChatNotifier extends Notifier<ChatState> {
  final String arg;
  ChatNotifier(this.arg);

  MessageService get _service => ref.read(messageServiceProvider);

  @override
  ChatState build() {
    Future.microtask(() => loadMessages());
    return ChatState(conversationId: arg);
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.getMessages(conversationId: arg);
      final List<MessageModel> messages = (result['messages'] as List).cast<MessageModel>();
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 30, 
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final result = await _service.getMessages(
        conversationId: arg,
        page: nextPage,
      );
      final List<MessageModel> newMessages = (result['messages'] as List).cast<MessageModel>();

      state = state.copyWith(
        messages: [...state.messages, ...newMessages],
        isLoadingMore: false,
        page: nextPage,
        hasMore: newMessages.length >= 30,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> sendMessage(String content, {String? messageType}) async {
    state = state.copyWith(isSending: true, errorMessage: null);

    try {
      final replyToId = state.replyingTo?.id;

      final message = await _service.sendMessage(
        conversationId: arg,
        content: content,
        messageType: messageType ?? 'text',
        replyToMessageId: replyToId,
      );

      state = state.copyWith(
        messages: [message, ...state.messages],
        isSending: false,
        replyingTo: null,
        clearReplyingTo: true,
      );

      // Update inbox preview too
      ref.read(inboxProvider.notifier).updateConversationLastMessage(
            arg,
            content.isNotEmpty ? content : 'Sent a ${messageType ?? 'message'}',
          );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> unsendMessage(String messageId) async {
    try {
      await _service.deleteMessage(messageId);
      // Update local state
      final List<MessageModel> updated = state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(isDeleted: true);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> deleteMessage(String messageId) => unsendMessage(messageId);

  // ─── SET REPLYING TO ─────────────────────────────────────
  void setReplyingTo(MessageModel? message) {
    state = state.copyWith(
      replyingTo: message,
      clearReplyingTo: message == null,
    );
  }

  // ─── ADD NEW MESSAGE (from socket) ──────────────
  void addNewMessage(MessageModel message) {
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
final inboxProvider = NotifierProvider<InboxNotifier, InboxState>(
  InboxNotifier.new,
);

// DM unread count provider
final dmUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(inboxProvider).dmUnreadCount;
});

// Per-conversation chat provider (family)
final chatProvider =
    NotifierProvider.family<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);