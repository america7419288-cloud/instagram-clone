// lib/features/messages/presentation/pages/new_message_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/message_search_provider.dart';
import '../providers/message_provider.dart';
import '../../../../shared/widgets/spring_widget.dart';

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

              if (conversation != null) {
                // Pop loading
                Navigator.pop(context);
                // Navigate to chat
                context.pushReplacement(
                  '/chat/${conversation.id}',
                  extra: conversation,
                );
              } else {
                Navigator.pop(context); // Pop loading
                // Handle null case if needed, but error is usually in catch
              }
            } catch (e) {
              if (!context.mounted) return;
              Navigator.pop(context); // Pop loading
              AppSnackbar.error(context, 'Error: $e');
            }
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.border,
              backgroundImage: user.profilePicUrl != null
                  ? CachedNetworkImageProvider(user.profilePicUrl!)
                  : null,
              child: user.profilePicUrl == null
                  ? Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.textPrimary),
                    )
                  : null,
            ),
            title: Text(
              user.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
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

