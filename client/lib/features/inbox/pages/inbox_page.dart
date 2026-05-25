// lib/features/inbox/pages/inbox_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSearchTextField;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/router/app_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../controllers/inbox_controller.dart';
import '../widgets/inbox_app_bar.dart';
import '../widgets/message_requests_tile.dart';
import '../widgets/active_friends_bar.dart';
import '../widgets/conversation_tile.dart';
import '../../notes/pages/note_create_sheet.dart';
import '../../notes/controllers/notes_controller.dart';
import '../../chat/presentation/providers/chat_providers.dart';
import '../../chat/presentation/providers/chat_notifiers.dart';
import '../../communities/presentation/pages/community_discover_page.dart';
import '../../follow/data/repositories/presentation/providers/follow_provider.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage>
    with TickerProviderStateMixin {

  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  
  // Entry animations
  late AnimationController _entryController;
  late Animation<double> _appBarOpacity;
  late Animation<Offset> _requestsSlide;
  late Animation<double> _requestsOpacity;

  // Scroll offset for appBar collapsing header
  double _scrollOffset = 0;
  bool _showLargeTitle = false;

  @override
  void initState() {
    super.initState();
    _setupEntryAnimations();
    _setupScrollListener();
    _playEntryAnimation();
  }

  void _setupEntryAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _appBarOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _requestsSlide = Tween<Offset>(
      begin: const Offset(0.15, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    ));

    _requestsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
          _showLargeTitle = _scrollOffset > 24;
        });
      }
    });
  }

  void _playEntryAnimation() {
    // Staggered entry onset
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _entryController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _openChat(String id, String username) {
    // standard push transition
    context.push(
      AppRoutes.chat.replaceAll(':conversationId', id),
      extra: {
        'username': username,
        'isVerified': false,
      },
    );
  }

  void _openNewMessage() {
    context.push(AppRoutes.newMessage);
  }

  void _openVideoCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting video call...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openMessageRequests() {
    context.push(AppRoutes.messageRequests);
  }
  void _openNoteCreator() {
    final existingNote = ref.read(notesProvider).myNote;
    NoteCreateSheet.show(context, existingNote: existingNote);
  }

  Future<void> _onRefresh() async {
    // Refresh inbox conversations, active friends, and notes in parallel
    await Future.wait([
      ref.read(inboxProvider.notifier).refresh(),
      ref.read(notesProvider.notifier).fetchNotesFeed(),
      ref.read(authProvider.notifier).refreshUser(),
    ]);
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final inboxState = ref.watch(inboxPageProvider);
    final notifier = ref.read(inboxPageProvider.notifier);

    final String username = currentUser?.username ?? 'your_username';
    final String? avatarUrl = currentUser?.profilePicUrl;

    final filteredConversations = inboxState.conversations.where((conv) {
      if (_searchQuery.isEmpty) return true;
      return conv.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          conv.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 60,
            color: isDark ? Colors.white : Colors.black,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // TOP APP BAR
              SliverToBoxAdapter(
                child: Opacity(
                  opacity: _appBarOpacity.value,
                  child: InboxAppBar(
                    username: username,
                    scrollOffset: _scrollOffset,
                    onBackTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        context.pop();
                      }
                    },
                    onComposeTap: _openNewMessage,
                    onVideoCallTap: _openVideoCall,
                    onCommunitiesTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CommunityDiscoverPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // MESSAGE REQUESTS
              if (inboxState.requestCount > 0)
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _requestsSlide,
                    child: FadeTransition(
                      opacity: _requestsOpacity,
                      child: MessageRequestsTile(
                        count: inboxState.requestCount,
                        avatarUrls: inboxState.requests
                            .take(2)
                            .map((r) => r.avatarUrl)
                            .toList(),
                        onTap: _openMessageRequests,
                      ),
                    ),
                  ),
                ),

              // ACTIVE FRIENDS HORIZONTAL BAR
              SliverToBoxAdapter(
                child: ActiveFriendsBar(
                  friends: inboxState.activeFriends,
                  entryController: _entryController,
                  currentUserAvatar: avatarUrl,
                  onFriendTap: (friend) => _openChat(friend.conversationId, friend.username),
                  onNoteTap: _openNoteCreator,
                ),
              ),

              // MESSAGES HEADER LABEL & SEARCH BAR
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessagesLabel(),
                    _buildSearchBar(isDark),
                  ],
                ),
              ),

              // CONVERSATION LIST (EMPTY STATE OR TILES)
              if (inboxState.conversations.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.mail, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Messages Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredConversations.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conv = filteredConversations[index];
                      return ConversationTile(
                        conversation: conv,
                        index: index,
                        entryController: _entryController,
                        onTap: () => _openChat(conv.id, conv.username),
                        onDelete: () => notifier.deleteConversation(conv.id),
                        onMute: (duration) => notifier.muteConversation(conv.id, duration: duration),
                        onUnmute: () => notifier.unmuteConversation(conv.id),
                        onToggleRead: () => notifier.toggleReadState(conv.id),
                        onReport: (type, desc) => ref.read(messageRepositoryProvider).reportUser(userId: conv.userId, reportType: type, description: desc),
                        onBlock: () async {
                          HapticFeedback.heavyImpact();
                          await ref.read(followServiceProvider).blockUser(conv.userId);
                          notifier.deleteConversation(conv.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${conv.username} blocked')),
                            );
                          }
                        },
                      );
                    },
                    childCount: filteredConversations.length,
                  ),
                ),

              // Bottom offset padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesLabel() {
    // When scrolled, we transition the messages header out
    final double headerOpacity = _showLargeTitle ? 0.0 : 1.0;
    
    return AnimatedOpacity(
      opacity: headerOpacity,
      duration: const Duration(milliseconds: 200),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Messages',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: CupertinoSearchTextField(
        placeholder: 'Search',
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        placeholderStyle: const TextStyle(color: Colors.grey),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
}
