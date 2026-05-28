import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';

import 'package:instagram_client/shared/widgets/ios_app_bar.dart';

class CloseFriendsPage extends ConsumerStatefulWidget {
  const CloseFriendsPage({super.key});

  @override
  ConsumerState<CloseFriendsPage> createState() => _CloseFriendsPageState();
}

class _CloseFriendsPageState extends ConsumerState<CloseFriendsPage> {
  final _searchController = TextEditingController();
  List<dynamic> _closeFriends = [];
  List<dynamic> _following = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getCloseFriends();
      
      final currentUserId = ref.read(authProvider).user?.id;
      List<dynamic> followingList = [];
      if (currentUserId != null) {
        final followRes = await ref.read(followServiceProvider).getFollowing(
          userId: currentUserId,
          limit: 100,
        );
        followingList = followRes['users'] as List<dynamic>;
      }

      setState(() {
        _closeFriends = list;
        _following = followingList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });
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
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCloseFriend(dynamic user, bool isAdded) async {
    final repo = ref.read(settingsRepositoryProvider);
    final userId = user['id'] ?? user['_id'];
    try {
      if (isAdded) {
        await repo.removeCloseFriend(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${user['username']} from Close Friends')),
        );
      } else {
        await repo.addCloseFriend(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${user['username']} to Close Friends'), backgroundColor: Colors.green),
        );
      }
      
      // Reload close friends
      final updatedList = await repo.getCloseFriends();
      if (!mounted) return;
      setState(() {
        _closeFriends = updatedList;
      });

      if (_searchController.text.isNotEmpty) {
        _searchUsers(_searchController.text);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  List<dynamic> get _suggestedFriends {
    final closeFriendIds = _closeFriends.map((f) => f['id'] ?? f['_id']).toSet();
    return _following.where((f) {
      final id = f['id'] ?? f['_id'];
      return !closeFriendIds.contains(id);
    }).toList();
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(dynamic itemUser, bool isDark) {
    final itemUserId = itemUser['id'] ?? itemUser['_id'];
    final isAdded = _closeFriends.any((f) => (f['id'] ?? f['_id']) == itemUserId);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: itemUser['profile_pic_url'] != null && itemUser['profile_pic_url'].toString().isNotEmpty
            ? NetworkImage(itemUser['profile_pic_url'])
            : null,
        backgroundColor: Colors.grey[300],
        child: itemUser['profile_pic_url'] == null || itemUser['profile_pic_url'].toString().isEmpty
            ? const Icon(LucideIcons.user, color: Colors.white)
            : null,
      ),
      title: Text(itemUser['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(itemUser['fullName'] ?? itemUser['fullname'] ?? itemUser['full_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: GestureDetector(
        onTap: () => _toggleCloseFriend(itemUser, isAdded),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAdded ? Colors.green : Colors.transparent,
            border: Border.all(
              color: isAdded ? Colors.green : Colors.grey.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            LucideIcons.star,
            size: 16,
            color: isAdded ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    // Build a list of elements dynamically
    final List<Widget> listItems = [];
    
    if (_isSearching) {
      if (_searchResults.isEmpty) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(top: 64.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.star, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No users found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        for (var item in _searchResults) {
          listItems.add(_buildUserTile(item, isDark));
        }
      }
    } else {
      // 1. Close Friends Section
      if (_closeFriends.isNotEmpty) {
        listItems.add(_buildSectionHeader('Close Friends', _closeFriends.length));
        for (var item in _closeFriends) {
          listItems.add(_buildUserTile(item, isDark));
        }
      }
      
      // 2. Suggested Section (Following)
      final suggested = _suggestedFriends;
      if (suggested.isNotEmpty) {
        listItems.add(_buildSectionHeader('Suggested Close Friends', suggested.length));
        for (var item in suggested) {
          listItems.add(_buildUserTile(item, isDark));
        }
      }
      
      if (_closeFriends.isEmpty && suggested.isEmpty) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(top: 64.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.star, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Close Friends yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share your stories and notes with a selected group of friends.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: const IOSAppBar(
        title: 'Close Friends',
        previousTitle: 'Privacy',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search',
              onChanged: _searchUsers,
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            ),
          ),
          if (_isLoading && listItems.isEmpty)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))
          else
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: listItems,
              ),
            ),
        ],
      ),
    );
  }
}
