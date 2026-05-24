import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';

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
      appBar: AppBar(
        title: const Text('Muted Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
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
