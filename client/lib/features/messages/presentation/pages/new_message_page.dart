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

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Icon(LucideIcons.x, color: AppColors.textPrimary),
            ),
          ),
        ),
        title: const Text(
          'New message',
          style: TextStyle(
            color: AppColors.textPrimary,
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
                const Text(
                  'To: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(messageSearchProvider.notifier).search(value),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ─── RESULTS ──────────────────────────────────────────
          Expanded(child: _buildBody(searchState)),
        ],
      ),
    );
  }

  Widget _buildBody(MessageSearchState state) {
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

    if (state.users.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (state.users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Suggested',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.users.length,
      itemBuilder: (context, index) {
        final user = state.users[index];
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}
