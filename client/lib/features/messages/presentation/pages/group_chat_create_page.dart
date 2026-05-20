import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/message_search_provider.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

class GroupChatCreatePage extends ConsumerStatefulWidget {
  const GroupChatCreatePage({super.key});

  @override
  ConsumerState<GroupChatCreatePage> createState() => _GroupChatCreatePageState();
}

class _GroupChatCreatePageState extends ConsumerState<GroupChatCreatePage> {
  final Map<String, UserModel> _selectedUsers = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  bool _showNameInput = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggleSelection(UserModel user) {
    setState(() {
      if (_selectedUsers.containsKey(user.id)) {
        _selectedUsers.remove(user.id);
      } else {
        _selectedUsers[user.id] = user;
      }
    });
  }

  void _handleNext() {
    if (_selectedUsers.length < 2) {
      _showError('Select at least 2 people');
      return;
    }
    setState(() {
      _showNameInput = true;
    });
  }

  Future<void> _handleCreate() async {
    if (_groupNameController.text.trim().isEmpty) {
      _showError('Enter a group name');
      return;
    }

    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CupertinoActivityIndicator(radius: 14),
        ),
      );

      final conversation = await ref.read(messageRepositoryProvider).createGroupConversation(
        name: _groupNameController.text.trim(),
        participantIds: _selectedUsers.keys.toList(),
      );

      // Pop loading
      if (mounted) Navigator.pop(context);

      // Clear search state
      ref.read(messageSearchProvider.notifier).clear();

      // Refresh inbox list
      ref.read(inboxProvider.notifier).refresh();

      // Navigate straight to the new room!
      if (mounted) {
        context.go('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
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

    if (_showNameInput) {
      return _buildNameInputPage(bgColor, isDark);
    }

    return _buildMemberSelectionPage(bgColor, isDark);
  }

  Widget _buildMemberSelectionPage(Color bgColor, bool isDark) {
    final searchState = ref.watch(messageSearchProvider);

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
          onTap: () {
            ref.read(messageSearchProvider.notifier).clear();
            context.pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
            ),
          ),
        ),
        middle: const Text(
          'New Group',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        trailing: BouncyTap(
          onTap: _selectedUsers.length >= 2 ? _handleNext : null,
          child: Text(
            'Next',
            style: TextStyle(
              color: _selectedUsers.length >= 2
                  ? AppColors.primary
                  : AppColors.textSecondary,
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
                onChanged: (value) =>
                    ref.read(messageSearchProvider.notifier).search(value),
              ),
            ),

            // Selected Users Chips
            if (_selectedUsers.isNotEmpty)
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _selectedUsers.values.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _SelectedUserChip(
                        user: user,
                        onRemove: () => _toggleSelection(user),
                      ),
                    );
                  },
                ),
              ),

            // Users List
            Expanded(
              child: searchState.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : (searchState.users.isEmpty && _searchController.text.isNotEmpty)
                      ? Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(
                              color: isDark ? Colors.grey : Colors.grey[600],
                            ),
                          ),
                        )
                      : (searchState.users.isEmpty)
                          ? Center(
                              child: Text(
                                'Type to search friends',
                                style: TextStyle(
                                  color: isDark ? Colors.grey : Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: searchState.users.length,
                              itemBuilder: (context, index) {
                                final user = searchState.users[index];
                                final isSelected = _selectedUsers.containsKey(user.id);

                                return _UserSelectionTile(
                                  user: user,
                                  isSelected: isSelected,
                                  onTap: () => _toggleSelection(user),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInputPage(Color bgColor, bool isDark) {
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
          onTap: () {
            setState(() {
              _showNameInput = false;
            });
          },
          child: const Icon(
            LucideIcons.chevronLeft,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
        middle: const Text(
          'Name Group',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        trailing: BouncyTap(
          onTap: _handleCreate,
          child: const Text(
            'Create',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Group Avatar
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.border,
                  ),
                  child: const Icon(
                    LucideIcons.users,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 2),
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Group Name Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: _groupNameController,
                placeholder: 'Group name',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Members Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'MEMBERS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedUsers.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Selected Members List
            Expanded(
              child: ListView.builder(
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers.values.elementAt(index);
                  return _MemberListTile(
                    user: user,
                    onRemove: () => _toggleSelection(user),
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

class _SelectedUserChip extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRemove;

  const _SelectedUserChip({
    required this.user,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.profilePicUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          LucideIcons.user,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          LucideIcons.user,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserSelectionTile extends StatelessWidget {
  final UserModel user;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserSelectionTile({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.border,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.profilePicUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          LucideIcons.user,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          LucideIcons.user,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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

class _MemberListTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRemove;

  const _MemberListTile({
    required this.user,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.border,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.profilePicUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                        LucideIcons.user,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : const Center(
                      child: Icon(
                        LucideIcons.user,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.username,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            child: const Icon(
              LucideIcons.x,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
