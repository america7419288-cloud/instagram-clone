import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';

import 'package:instagram_client/shared/widgets/ios_app_bar.dart';

class BlockedAccountsPage extends ConsumerStatefulWidget {
  const BlockedAccountsPage({super.key});

  @override
  ConsumerState<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends ConsumerState<BlockedAccountsPage> {
  List<dynamic> _blockedAccounts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedAccounts();
  }

  Future<void> _loadBlockedAccounts() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getBlockedAccounts();
      setState(() {
        _blockedAccounts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _unblockAccount(String userId) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.unblockAccount(userId);
      _loadBlockedAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account unblocked')),
      );
    } catch (e) {
      _showError(e.toString());
    }
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
      appBar: const IOSAppBar(
        title: 'Blocked Accounts',
        previousTitle: 'Privacy',
      ),
      body: _isLoading && _blockedAccounts.isEmpty
          ? const Center(child: CupertinoActivityIndicator())
          : _blockedAccounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.ban, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'No blocked accounts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can block people from their profiles.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _blockedAccounts.length,
                  itemBuilder: (context, index) {
                    final item = _blockedAccounts[index];
                    final user = item['user'];
                    if (user == null) return const SizedBox.shrink();
                    final userId = user['id'] ?? user['_id'];

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
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () => _unblockAccount(userId),
                        child: const Text(
                          'Unblock',
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
    );
  }
}
