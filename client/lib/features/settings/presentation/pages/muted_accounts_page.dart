import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../core/network/dio_client.dart';

import 'package:instagram_client/shared/widgets/ios_app_bar.dart';

class MutedAccountsPage extends ConsumerStatefulWidget {
  const MutedAccountsPage({super.key});

  @override
  ConsumerState<MutedAccountsPage> createState() => _MutedAccountsPageState();
}

class _MutedAccountsPageState extends ConsumerState<MutedAccountsPage> {
  List<dynamic> _mutedAccounts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMutedAccounts();
  }

  Future<void> _loadMutedAccounts() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getMutedAccounts();
      setState(() {
        _mutedAccounts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _unmuteAccount(String userId) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.unmuteAccount(userId);
      _loadMutedAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account unmuted')),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _updateMuteSettings(String userId, bool mutePosts, bool muteStories) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateMuteSettings(userId, mutePosts: mutePosts, muteStories: muteStories);
      _loadMutedAccounts();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showMuteSettingsSheet(dynamic item) {
    final user = item['user'];
    final userId = user['id'] ?? user['_id'];
    bool mutePosts = item['mutePosts'] ?? true;
    bool muteStories = item['muteStories'] ?? false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => CupertinoActionSheet(
          title: Text('Muted: ${user['username']}'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                mutePosts = !mutePosts;
                setSheetState(() {});
                _updateMuteSettings(userId, mutePosts, muteStories);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mute Posts', style: TextStyle(fontSize: 16)),
                  Icon(
                    mutePosts ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    color: mutePosts ? const Color(0xFF0095F6) : Colors.grey,
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                muteStories = !muteStories;
                setSheetState(() {});
                _updateMuteSettings(userId, mutePosts, muteStories);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mute Stories', style: TextStyle(fontSize: 16)),
                  Icon(
                    muteStories ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    color: muteStories ? const Color(0xFF0095F6) : Colors.grey,
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _unmuteAccount(userId);
              },
              isDestructiveAction: true,
              child: const Text('Unmute Entirely'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }

  void _showAddMuteBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMuteBottomSheet(
        onAccountMuted: () {
          _loadMutedAccounts();
        },
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: IOSAppBar(
        title: 'Muted Accounts',
        previousTitle: 'Privacy',
        actions: [
          IconButton(
            icon: Icon(LucideIcons.user_plus, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showAddMuteBottomSheet(context),
          ),
        ],
      ),
      body: _isLoading && _mutedAccounts.isEmpty
          ? const Center(child: CupertinoActivityIndicator())
          : _mutedAccounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.volume_2, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'No muted accounts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accounts you mute will appear here.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _mutedAccounts.length,
                  itemBuilder: (context, index) {
                    final item = _mutedAccounts[index];
                    final user = item['user'];
                    if (user == null) return const SizedBox.shrink();

                    List<String> mutedList = [];
                    if (item['mutePosts'] == true) mutedList.add('posts');
                    if (item['muteStories'] == true) mutedList.add('stories');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profile_pic_url'] != null && user['profile_pic_url'].toString().isNotEmpty
                            ? NetworkImage(user['profile_pic_url'])
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: user['profile_pic_url'] == null || user['profile_pic_url'].toString().isEmpty
                            ? const Icon(LucideIcons.user, color: Colors.white)
                            : null,
                      ),
                      title: Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Muted ${mutedList.join(' & ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () => _showMuteSettingsSheet(item),
                        child: Text(
                          'Options',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── ADD MUTE BOTTOM SHEET ──────────────────────────────────

class _AddMuteBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onAccountMuted;
  const _AddMuteBottomSheet({required this.onAccountMuted});

  @override
  ConsumerState<_AddMuteBottomSheet> createState() => _AddMuteBottomSheetState();
}

class _AddMuteBottomSheetState extends ConsumerState<_AddMuteBottomSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioClientProvider).get('/users/search', queryParameters: {'q': query});
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final list = data is List
            ? data
            : (data is Map && data['users'] != null ? data['users'] as List<dynamic> : []);
        setState(() {
          _searchResults = list;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _muteUser(dynamic user, bool mutePosts, bool muteStories) async {
    final userId = user['id'] ?? user['_id'];
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.muteAccount(userId, mutePosts: mutePosts, muteStories: muteStories);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Muted @${user['username']}'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAccountMuted();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mute user: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMuteOptions(dynamic user) {
    bool mutePosts = true;
    bool muteStories = false;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => CupertinoActionSheet(
          title: Text('Mute @${user['username']}?'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                mutePosts = !mutePosts;
                setSheetState(() {});
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mute Posts', style: TextStyle(fontSize: 16)),
                  Icon(
                    mutePosts ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    color: mutePosts ? const Color(0xFF0095F6) : Colors.grey,
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                muteStories = !muteStories;
                setSheetState(() {});
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mute Stories', style: TextStyle(fontSize: 16)),
                  Icon(
                    muteStories ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    color: muteStories ? const Color(0xFF0095F6) : Colors.grey,
                  ),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _muteUser(user, mutePosts, muteStories);
              },
              child: const Text('Confirm Mute', style: TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.activeBlue)),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          ),
          padding: EdgeInsets.only(bottom: viewInsetsBottom > 0 ? viewInsetsBottom : safeAreaBottom),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mute Account',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Search user',
                  onChanged: _searchUsers,
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
              // Search results list
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Type to search users'
                                  : 'No users found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['profile_pic_url'] != null && user['profile_pic_url'].toString().isNotEmpty
                                      ? NetworkImage(user['profile_pic_url'])
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                  child: user['profile_pic_url'] == null || user['profile_pic_url'].toString().isEmpty
                                      ? const Icon(LucideIcons.user, color: Colors.white)
                                      : null,
                                ),
                                title: Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(user['fullName'] ?? user['fullname'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  color: const Color(0xFF0095F6),
                                  borderRadius: BorderRadius.circular(8),
                                  onPressed: () => _showMuteOptions(user),
                                  child: const Text(
                                    'Mute',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
