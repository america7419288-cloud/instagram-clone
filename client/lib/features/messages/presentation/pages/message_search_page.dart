import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../chat/data/models/message.dart';
import '../../../chat/data/models/conversation.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';

class SearchResult {
  final Message message;
  final Conversation conversation;

  SearchResult({required this.message, required this.conversation});
}

class MessageSearchPage extends ConsumerStatefulWidget {
  const MessageSearchPage({super.key});

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    
    // Get conversations and search locally
    final conversations = ref.watch(inboxProvider).conversations;
    final results = _searchResults(conversations);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: const Icon(
            LucideIcons.chevron_left,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
        middle: const Text(
          'Search Messages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                focusNode: _searchFocus,
                placeholder: 'Search messages...',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Results
            Expanded(
              child: _buildResults(results),
            ),
          ],
        ),
      ),
    );
  }

  List<SearchResult> _searchResults(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return [];

    final results = <SearchResult>[];
    for (final conv in conversations) {
      final messages = ref.read(chatProvider(conv.id)).messages;
      
      for (final message in messages) {
        if (message.content.toLowerCase().contains(_searchQuery.toLowerCase())) {
          results.add(SearchResult(
            message: message,
            conversation: conv,
          ));
        }
      }
    }
    return results;
  }

  Widget _buildResults(List<SearchResult> results) {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.search,
        title: 'Search Messages',
        subtitle: 'Find messages across all conversations',
      );
    }

    if (results.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.search,
        title: 'No Results',
        subtitle: 'Try searching for something else',
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          query: _searchQuery,
          onTap: () {
            context.push('/chat/${result.conversation.id}');
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  String _highlightText(String text, String query) {
    return text; // In real implementation, you'd highlight the matching text
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = result.message;
    final conversation = result.conversation;
    final timeText = timeago.format(message.createdAt, locale: 'en_short');

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: ClipOval(
                child: conversation.otherUser?.profilePicUrl != null
                    ? CachedNetworkImage(
                        imageUrl: conversation.otherUser!.profilePicUrl!,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          conversation.otherUser?.username[0].toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                conversation.otherUser?.username ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.otherUser?.isVerified == true) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 13),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
