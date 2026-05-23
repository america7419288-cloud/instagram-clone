// lib/features/inbox/controllers/inbox_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_model.dart';
import '../models/active_friend_model.dart';

// Real backend providers imports
import 'package:instagram_client/features/chat/presentation/providers/chat_notifiers.dart';
import 'package:instagram_client/features/chat/presentation/providers/presence_provider.dart';
import 'package:instagram_client/features/chat/presentation/providers/typing_provider.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';
import 'package:instagram_client/features/chat/data/models/conversation.dart';

class InboxPageState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> requests;
  final List<ActiveFriendModel> activeFriends;
  final int requestCount;
  final bool isLoading;
  final String? errorMessage;

  const InboxPageState({
    this.conversations = const [],
    this.requests = const [],
    this.activeFriends = const [],
    this.requestCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  InboxPageState copyWith({
    List<ConversationModel>? conversations,
    List<ConversationModel>? requests,
    List<ActiveFriendModel>? activeFriends,
    int? requestCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InboxPageState(
      conversations: conversations ?? this.conversations,
      requests: requests ?? this.requests,
      activeFriends: activeFriends ?? this.activeFriends,
      requestCount: requestCount ?? this.requestCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class InboxPageNotifier extends Notifier<InboxPageState> {
  @override
  InboxPageState build() {
    final inboxState = ref.watch(inboxProvider);
    final presenceState = ref.watch(presenceProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    // Track presence of all conversation participants
    final List<String> trackUserIds = [];
    for (final c in inboxState.conversations) {
      if (c.otherUser != null) {
        trackUserIds.add(c.otherUser!.id);
      }
    }
    if (trackUserIds.isNotEmpty) {
      // Trigger user tracking safely within build/microtask
      Future.microtask(() {
        ref.read(presenceProvider.notifier).trackUsers(trackUserIds);
      });
    }

    // Build active friends list from real online users
    final onlineUsers = presenceState.onlineUsers;
    final List<ActiveFriendModel> activeFriends = [];
    for (final conv in inboxState.conversations) {
      if (conv.otherUser != null) {
        final otherUser = conv.otherUser!;
        final isOnline = onlineUsers[otherUser.id] == true;
        if (isOnline) {
          activeFriends.add(
            ActiveFriendModel(
              id: otherUser.id,
              username: otherUser.username,
              avatarUrl: otherUser.profilePicUrl ?? '',
              isActive: true,
              conversationId: conv.id,
              hasActiveNote: false,
              noteText: null,
            ),
          );
        }
      }
    }

    // Map real Conversation objects to high-fidelity ConversationModel objects
    final mapConv = (Conversation conv) {
      final otherUser = conv.otherUser;
      final isOwn = conv.lastMessage?.senderId == currentUserId;
      
      LastMessageType lastMsgType = LastMessageType.text;
      if (conv.lastMessage != null) {
        final mt = conv.lastMessage!.messageType;
        if (mt == 'image') lastMsgType = LastMessageType.image;
        else if (mt == 'video' || conv.lastMessage!.reelId != null) lastMsgType = LastMessageType.reel;
        else if (conv.lastMessage!.postId != null) lastMsgType = LastMessageType.post;
        else if (conv.lastMessage!.storyId != null) lastMsgType = LastMessageType.story;
        else if (mt == 'voice') lastMsgType = LastMessageType.voice;
        else if (mt == 'gif') lastMsgType = LastMessageType.gif;
        else if (mt == 'like') lastMsgType = LastMessageType.like;
      }

      final isTyping = ref.watch(typingProvider(conv.id)).isTyping;
      final isOnline = otherUser != null ? (onlineUsers[otherUser.id] == true) : false;
      final lastActiveTime = otherUser != null ? presenceState.lastSeen[otherUser.id] : null;

      ConversationState conversationState = ConversationState.read;
      if (conv.isMuted) {
        conversationState = ConversationState.muted;
      } else if (conv.isUnread || conv.unreadCount > 0) {
        conversationState = ConversationState.unread;
      }

      return ConversationModel(
        id: conv.id,
        userId: otherUser?.id ?? '',
        username: conv.isGroup ? (conv.name ?? 'Group Chat') : (otherUser?.username ?? 'User'),
        avatarUrl: conv.isGroup ? (conv.avatarUrl ?? '') : (otherUser?.profilePicUrl ?? ''),
        isVerified: otherUser?.isVerified ?? false,
        isGroup: conv.isGroup,
        groupAvatars: conv.isGroup 
            ? conv.participants.map((p) => p.profilePicUrl ?? '').where((u) => u.isNotEmpty).toList() 
            : const [],
        lastMessage: () {
          final rawContent = conv.lastMessage?.content;
          if (rawContent != null && rawContent.startsWith('[note_reply]:')) {
            return '↩ Replied to your note';
          }
          return rawContent ?? (conv.isAccepted ? 'Start a conversation' : 'Sent a message request');
        }(),
        lastMessageType: lastMsgType,
        lastMessageTime: conv.lastMessage?.createdAt ?? conv.updatedAt,
        isSentByMe: isOwn,
        unreadCount: conv.isUnread && conv.unreadCount == 0 ? 1 : conv.unreadCount,
        isActive: isOnline,
        lastActiveTime: lastActiveTime,
        isMuted: conv.isMuted, 
        hasStory: false,
        isTyping: isTyping,
        state: conversationState,
      );
    };

    final conversations = inboxState.conversations.map<ConversationModel>(mapConv).toList();
    final requests = inboxState.requests.map<ConversationModel>(mapConv).toList();

    return InboxPageState(
      conversations: conversations,
      requests: requests,
      activeFriends: activeFriends,
      requestCount: requests.length,
      isLoading: inboxState.isLoading,
      errorMessage: inboxState.error,
    );
  }

  void toggleReadState(String id) {
    try {
      final conv = state.conversations.firstWhere((c) => c.id == id);
      if (conv.state == ConversationState.unread) {
        ref.read(inboxProvider.notifier).markAsRead(id);
      } else {
        ref.read(inboxProvider.notifier).markAsUnread(id);
      }
    } catch (e) {
      // Guard against not found in active list (check requests)
      try {
        final conv = state.requests.firstWhere((c) => c.id == id);
        if (conv.state == ConversationState.unread) {
          ref.read(inboxProvider.notifier).markAsRead(id);
        } else {
          ref.read(inboxProvider.notifier).markAsUnread(id);
        }
      } catch (_) {}
    }
  }

  void muteConversation(String id, {String duration = 'forever'}) {
    ref.read(inboxProvider.notifier).muteConversation(id, duration);
  }

  void unmuteConversation(String id) {
    ref.read(inboxProvider.notifier).unmuteConversation(id);
  }

  void deleteConversation(String id) {
    ref.read(inboxProvider.notifier).deleteConversation(id);
  }

  void addNewMessage(ConversationModel conversation) {
    // Backend socket automatically handles new messages and refreshes conversations
  }
}

final inboxPageProvider = NotifierProvider<InboxPageNotifier, InboxPageState>(
  InboxPageNotifier.new,
);
