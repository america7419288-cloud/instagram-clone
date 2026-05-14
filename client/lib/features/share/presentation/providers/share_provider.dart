// lib/features/share/presentation/providers/share_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/share_target.dart';
import '../../models/share_content.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../search/presentation/pages/providers/search_provider.dart';

class ShareSheetState {
  final List<ShareTarget> selectedTargets;
  final List<ShareTarget> recentTargets;
  final List<ShareTarget> searchResults;
  final bool isSearching;
  final bool isSending;
  final String searchQuery;
  final String? errorMessage;

  ShareSheetState({
    this.selectedTargets = const [],
    this.recentTargets = const [],
    this.searchResults = const [],
    this.isSearching = false,
    this.isSending = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  ShareSheetState copyWith({
    List<ShareTarget>? selectedTargets,
    List<ShareTarget>? recentTargets,
    List<ShareTarget>? searchResults,
    bool? isSearching,
    bool? isSending,
    String? searchQuery,
    String? errorMessage,
  }) {
    return ShareSheetState(
      selectedTargets: selectedTargets ?? this.selectedTargets,
      recentTargets: recentTargets ?? this.recentTargets,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      isSending: isSending ?? this.isSending,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class ShareSheetNotifier extends Notifier<ShareSheetState> {
  @override
  ShareSheetState build() {
    Future.microtask(() => _loadRecentTargets());
    return ShareSheetState();
  }

  void _loadRecentTargets() {
    final inboxState = ref.read(inboxProvider);
    final conversations = inboxState.conversations;

    final targets = conversations.map((conv) {
      return ShareTarget(
        id: conv.id,
        name: conv.participantName,
        avatarUrl: conv.participantAvatar,
        username: conv.participantUsername,
        type: conv.isGroup ? ShareTargetType.group : ShareTargetType.user,
        isRecent: true,
      );
    }).toList();

    state = state.copyWith(recentTargets: targets);
  }

  void toggleSelection(ShareTarget target) {
    final isSelected = state.selectedTargets.any((t) => t.id == target.id);
    if (isSelected) {
      state = state.copyWith(
        selectedTargets: state.selectedTargets.where((t) => t.id != target.id).toList(),
      );
    } else {
      state = state.copyWith(
        selectedTargets: [...state.selectedTargets, target],
      );
    }
  }

  void removeTarget(ShareTarget target) {
    state = state.copyWith(
      selectedTargets: state.selectedTargets.where((t) => t.id != target.id).toList(),
    );
  }

  Future<void> updateSearch(String query) async {
    state = state.copyWith(searchQuery: query, isSearching: true);
    if (query.isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }

    try {
      final searchService = ref.read(searchServiceProvider);
      final result = await searchService.searchUsers(query: query);
      final users = result['users'] as List<dynamic>;
      
      final targets = users.map((user) => ShareTarget(
        id: user['id'] ?? user['_id'] ?? '',
        name: user['fullName'] ?? user['username'] ?? '',
        avatarUrl: user['profilePic'],
        username: user['username'],
        type: ShareTargetType.user,
      )).toList();

      state = state.copyWith(searchResults: targets, isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: e.toString());
    }
  }

  Future<void> sendShare(ShareContent content, {String? message}) async {
    if (state.selectedTargets.isEmpty) return;

    state = state.copyWith(isSending: true);

    try {
      final messageService = ref.read(messageServiceProvider);
      
      for (final target in state.selectedTargets) {
        String conversationId = target.id;
        
        // If it's a new user from search, get/create conversation first
        if (!target.isRecent && target.type == ShareTargetType.user) {
          try {
            final conversation = await messageService.createOrGetConversation(target.id);
            conversationId = conversation.id;
          } catch (e) {
            debugPrint('Failed to create conversation with ${target.name}: $e');
            continue; // Skip this target if conversation creation fails
          }
        }

        // Build the message based on content type
        String defaultText = '';
        String? postId;
        String? reelId;
        String? storyId;
        String messageType = 'text';
        
        switch (content.type) {
          case ShareContentType.post:
            defaultText = 'Sent a post';
            postId = content.id;
            messageType = 'post';
            break;
          case ShareContentType.reel:
            defaultText = 'Sent a reel';
            reelId = content.id;
            messageType = 'reel';
            break;
          case ShareContentType.story:
            defaultText = 'Sent a story';
            storyId = content.id;
            messageType = 'story';
            break;
          case ShareContentType.profile:
            defaultText = 'Sent a profile';
            messageType = 'profile';
            break;
        }

        // Send actual message via API
        await messageService.sendMessage(
          conversationId: conversationId,
          content: (message != null && message.isNotEmpty) ? message : defaultText,
          messageType: messageType,
          postId: postId,
          reelId: reelId,
          storyId: storyId,
        );
      }

      state = state.copyWith(isSending: false, selectedTargets: []);
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      rethrow;
    }
  }
}

final shareSheetProvider = NotifierProvider.autoDispose<ShareSheetNotifier, ShareSheetState>(
  ShareSheetNotifier.new,
);
