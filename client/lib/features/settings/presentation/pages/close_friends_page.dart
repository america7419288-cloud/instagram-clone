import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../core/network/dio_client.dart';

class CloseFriendsPage extends ConsumerStatefulWidget {
  const CloseFriendsPage({super.key});

  @override
  ConsumerState<CloseFriendsPage> createState() => _CloseFriendsPageState();
}

class _CloseFriendsPageState extends ConsumerState<CloseFriendsPage> {
  final _searchController = TextEditingController();
  List<dynamic> _closeFriends = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCloseFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCloseFriends() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getCloseFriends();
      setState(() {
        _closeFriends = list;
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
      final repo = ref.read(settingsRepositoryProvider);
      // We will perform a search using the user search API
      final client = repo.getCloseFriends; // reference to repo
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
      // Fallback: search close friends locally
    }
  }

  Future<void> _toggleCloseFriend(dynamic user, bool isAdded) async {
    final repo = ref.read(settingsRepositoryProvider);
    final userId = user['id'] ?? user['_id'];
    try {
      if (isAdded) {
        await repo.removeCloseFriend(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${user['username']} from Close Friends')),
        );
      } else {
        await repo.addCloseFriend(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${user['username']} to Close Friends'), backgroundColor: Colors.green),
        );
      }
      _loadCloseFriends();
      if (_searchController.text.isNotEmpty) {
        _searchUsers(_searchController.text);
      }
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
    final displayList = _isSearching ? _searchResults : _closeFriends;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Close Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
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
          if (_isLoading && displayList.isEmpty)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))
          else if (displayList.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.star, size: 64, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      _isSearching ? 'No users found' : 'No Close Friends yet',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share your stories with a selected group of friends.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  final itemUser = _isSearching ? item : item; // user payload
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
                    subtitle: Text(itemUser['fullName'] ?? itemUser['fullname'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: GestureDetector(
                      onTap: () => _toggleCloseFriend(itemUser, isAdded),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAdded ? Colors.green : Colors.transparent,
                          border: Border.all(
                            color: isAdded ? Colors.green : Colors.grey.withOpacity(0.5),
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
                },
              ),
            ),
        ],
      ),
    );
  }
}
