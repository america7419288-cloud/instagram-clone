import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../chat/data/models/conversation.dart';
import '../../../chat/data/models/message.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';

class ForwardMessagePage extends ConsumerStatefulWidget {
  final Message message;

  const ForwardMessagePage({super.key, required this.message});

  @override
  ConsumerState<ForwardMessagePage> createState() => _ForwardMessagePageState();
}

class _ForwardMessagePageState extends ConsumerState<ForwardMessagePage> {
  final Set<String> _selectedConversations = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  Future<void> _handleForward() async {
    if (_selectedConversations.isEmpty) return;

    // Forward message to selected conversations
    for (final convId in _selectedConversations) {
      await ref.read(chatProvider(convId).notifier).sendMessage(
            widget.message.content,
            messageType: widget.message.messageType,
          );
    }

    if (mounted) {
      context.pop();
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Message Forwarded'),
        content: Text(
          'Sent to ${_selectedConversations.length} ${_selectedConversations.length == 1 ? "chat" : "chats"}',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final conversations = ref.watch(inboxProvider).conversations;

    final filteredConversations = _searchQuery.isEmpty
        ? conversations
        : conversations.where((conv) {
            final username = conv.otherUser?.username.toLowerCase() ?? '';
            return username.contains(_searchQuery.toLowerCase());
          }).toList();

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
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
            ),
          ),
        ),
        middle: const Text(
          'Forward',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        trailing: BouncyTap(
          onTap: _selectedConversations.isEmpty ? null : _handleForward,
          child: Text(
            'Send',
            style: TextStyle(
              color: _selectedConversations.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search',
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

            // Selected Count
            if (_selectedConversations.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark
                    ? Colors.grey[900]
                    : Colors.grey[100],
                child: Row(
                  children: [
                    Text(
                      '${_selectedConversations.length} selected',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Conversations List
            Expanded(
              child: ListView.builder(
                itemCount: filteredConversations.length,
                itemBuilder: (context, index) {
                  final conversation = filteredConversations[index];
                  final isSelected = _selectedConversations.contains(conversation.id);

                  return _ForwardConversationTile(
                    conversation: conversation,
                    isSelected: isSelected,
                    onTap: () => _toggleSelection(conversation.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForwardConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const _ForwardConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

            // Username
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      conversation.otherUser?.username ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
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

            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
