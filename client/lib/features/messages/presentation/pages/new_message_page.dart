// lib/features/messages/presentation/pages/new_message_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/ios_colors.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/user_story_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../providers/message_search_provider.dart';
import '../../../chat/presentation/providers/chat_notifiers.dart';
import '../../../../shared/models/user_model.dart';

class NewMessagePage extends ConsumerStatefulWidget {
  const NewMessagePage({super.key});

  @override
  ConsumerState<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends ConsumerState<NewMessagePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _entryCtrl.forward();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(messageSearchProvider.notifier).search(_searchCtrl.text);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    if (_selectedUserIds.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
      ),
    );

    try {
      if (_selectedUserIds.length == 1) {
        // Single user chat
        final targetId = _selectedUserIds.first;
        final conversation = await ref
            .read(inboxProvider.notifier)
            .createConversation(targetId);

        if (!mounted) return;
        Navigator.pop(context); // Pop loading

        if (conversation.id.isEmpty) {
          AppSnackbar.error(context, 'Could not open chat. Try again.');
          return;
        }

        context.pushReplacement(
          '/chat/${conversation.id}',
          extra: <String, dynamic>{
            'username': conversation.name ?? 'User',
            'avatarUrl': conversation.avatarUrl,
            'isVerified': conversation.otherUser?.isVerified ?? false,
          },
        );
      } else {
        // Multi-user Group chat
        Navigator.pop(context); // Pop loading first to show prompt
        final String? groupName = await _showGroupNamePrompt();
        if (groupName == null || groupName.isEmpty) return;

        // Show loading again
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
          ),
        );

        final conversation = await ref
            .read(inboxProvider.notifier)
            .createGroupConversation(
              name: groupName,
              participantIds: _selectedUserIds,
            );

        if (!mounted) return;
        Navigator.pop(context); // Pop loading

        if (conversation.id.isEmpty) {
          AppSnackbar.error(context, 'Could not open group. Try again.');
          return;
        }

        context.pushReplacement(
          '/chat/${conversation.id}',
          extra: <String, dynamic>{
            'username': conversation.name ?? groupName,
            'avatarUrl': conversation.avatarUrl,
            'isVerified': false,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        AppSnackbar.error(context, 'Error initiating chat: $e');
      }
    }
  }

  Future<String?> _showGroupNamePrompt() {
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: 'Group Chat');
        return CupertinoAlertDialog(
          title: const Text('New Group Name'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CupertinoTextField(
              controller: ctrl,
              placeholder: 'Group Name',
              placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText),
              autofocus: true,
              style: TextStyle(color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Create'),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = IosColors.background(context);
    final searchState = ref.watch(messageSearchProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildToField(isDark),
          if (_selectedUserIds.isNotEmpty) _buildSelectedChips(isDark, searchState.users),
          _buildToggleRow(isDark),
          const Divider(height: 0.5, thickness: 0.5),
          Expanded(child: _buildSuggestionsList(isDark, searchState)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: IosColors.background(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: CupertinoButton(
        padding: const EdgeInsets.only(left: 8),
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: IosColors.primary(context),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      title: Text(
        'New message',
        style: TextStyle(
          color: IosColors.primary(context),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
      actions: [
        AnimatedOpacity(
          opacity: _selectedUserIds.isNotEmpty ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _selectedUserIds.isEmpty ? null : _startChat,
            child: const Text(
              'Chat',
              style: TextStyle(
                color: IosColors.igBlue,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToField(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'To:  ',
            style: TextStyle(
              color: IosColors.primary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: _searchCtrl,
              autofocus: true,
              placeholder: 'Search...',
              placeholderStyle: TextStyle(
                color: IosColors.secondary(context),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              style: TextStyle(
                color: IosColors.primary(context),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              decoration: null,
              padding: EdgeInsets.zero,
              suffix: _searchCtrl.text.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(messageSearchProvider.notifier).clear();
                    },
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: IosColors.secondary(context),
                    ),
                  )
                : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips(bool isDark, List<UserModel> users) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _selectedUserIds.length,
        itemBuilder: (ctx, i) {
          final uid = _selectedUserIds[i];
          final user = users.firstWhere(
            (u) => u.id == uid,
            orElse: () => UserModel(
              id: uid,
              username: 'user',
              fullName: 'User',
              email: '',
              isPrivate: false,
              isVerified: false,
              isActive: true,
            ),
          );
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(
              scale: v.clamp(0.0, 1.0),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: IosColors.igBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: CachedNetworkImageProvider(user.profilePicUrl ?? 'https://i.pravatar.cc/150'),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: Color(0xFF0095F6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedUserIds.remove(uid));
                      },
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 16,
                        color: IosColors.igBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Suggested',
            style: TextStyle(
              color: IosColors.primary(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              HapticFeedback.selectionClick();
              AppSnackbar.info(context, 'Select 2 or more people to start a group chat');
            },
            child: const Text(
              'Create group',
              style: TextStyle(
                color: IosColors.igBlue,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark, MessageSearchState state) {
    if (state.isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 12));
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: IosColors.secondary(context),
            ),
            const SizedBox(height: 12),
            Text(
              'No account found.',
              style: TextStyle(
                color: IosColors.secondary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: state.users.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              AppSnackbar.info(context, 'Select 2 or more people to start a group chat');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.person_3_fill,
                      color: IosColors.igBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Group Chat',
                    style: TextStyle(
                      color: IosColors.igBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final user = state.users[i - 1];
        final isSelected = _selectedUserIds.contains(user.id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(user.id);
              } else {
                _selectedUserIds.add(user.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: Row(
              children: [
                UserStoryAvatar(
                  userId: user.id,
                  profilePicUrl: user.profilePicUrl,
                  username: user.username,
                  size: 44,
                  showPresence: false,
                  isClickable: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.username,
                            style: TextStyle(
                              color: IosColors.primary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 13),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.fullName,
                        style: TextStyle(
                          color: IosColors.secondary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
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
                      color: isSelected
                        ? IosColors.igBlue
                        : (isDark ? Colors.white30 : Colors.black26),
                      width: 1.5,
                    ),
                    color: isSelected ? IosColors.igBlue : Colors.transparent,
                  ),
                  child: isSelected
                    ? const Icon(
                        CupertinoIcons.checkmark,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
