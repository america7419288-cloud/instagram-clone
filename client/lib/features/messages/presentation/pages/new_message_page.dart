// lib/features/messages/presentation/pages/new_message_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/message_search_provider.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';

class NewMessagePage extends ConsumerStatefulWidget {
  const NewMessagePage({super.key});

  @override
  ConsumerState<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends ConsumerState<NewMessagePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(messageSearchProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(LucideIcons.x, color: textColor),
            ),
          ),
        ),
        title: Text(
          'New message',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          BouncyTap(
            onTap: () {
              // Create group logic could go here later
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Chat',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── SEARCH INPUT ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'To: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(messageSearchProvider.notifier).search(value),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: subtextColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

          // ─── RESULTS ──────────────────────────────────────────
          Expanded(child: _buildBody(searchState)),
        ],
      ),
    );
  }

  Widget _buildBody(MessageSearchState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white60 : Colors.black45;

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: const TextStyle(color: AppColors.secondary),
        ),
      );
    }

    final showGroupRow = _searchController.text.trim().isEmpty;

    if (state.users.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(color: subtextColor),
        ),
      );
    }

    final listCount = state.users.length + (showGroupRow ? 1 : 0);

    return ListView.builder(
      itemCount: listCount,
      itemBuilder: (context, index) {
        if (showGroupRow && index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BouncyTap(
                onTap: () {
                  context.push('/messages/group/create');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
                          ),
                          child: Icon(
                            LucideIcons.users,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Group Chat',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chat with up to 250 friends',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevron_right,
                          size: 16,
                          color: subtextColor,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                if (state.users.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Suggested',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ),
              ],
            );
        }

        final userIndex = showGroupRow ? index - 1 : index;
        final user = state.users[userIndex];
        return BouncyTap(
          onTap: () async {
            // Create or get conversation
            try {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );

              final conversation = await ref
                  .read(inboxProvider.notifier)
                  .createConversation(user.id);

              if (!context.mounted) return;

              // Always pop loading first
              Navigator.pop(context);

              // Guard: conversation ID must be non-empty for GoRouter to match /chat/:id
              if (conversation.id.isEmpty) {
                AppSnackbar.error(context, 'Could not open chat. Try again.');
                return;
              }

              // Pass a Map so the router's Map<String, dynamic> branch fires correctly
              context.pushReplacement(
                '/chat/${conversation.id}',
                extra: <String, dynamic>{
                  'username': conversation.name ?? user.username,
                  'avatarUrl': conversation.avatarUrl,
                  'isVerified':
                      conversation.otherUser?.isVerified ?? user.isVerified,
                },
              );
            } catch (e) {
              if (!context.mounted) return;
              Navigator.pop(context); // Pop loading
              AppSnackbar.error(context, 'Error: $e');
            }
          },
          child: ListTile(
            leading: UserStoryAvatar(
              userId: user.id,
              profilePicUrl: user.profilePicUrl,
              username: user.username,
              size: 40,
              showPresence: false,
              isClickable: true,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.username,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isVerified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 13),
                ],
              ],
            ),
            subtitle: Text(
              user.fullName,
              style: TextStyle(color: subtextColor),
            ),
          ),
        );
      },
    );
  }
}
