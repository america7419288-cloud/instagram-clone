import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';

class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  int _activeTab = 0; // 0 = Stories, 1 = Posts
  List<dynamic> _archivedStories = [];
  List<dynamic> _archivedPosts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadArchiveData();
  }

  Future<void> _loadArchiveData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      if (_activeTab == 0) {
        final list = await repo.getArchivedStories();
        setState(() {
          _archivedStories = list;
          _isLoading = false;
        });
      } else {
        final list = await repo.getArchivedPosts();
        setState(() {
          _archivedPosts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _unarchive(String type, String contentId) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.unarchiveContent(type, contentId);
      _loadArchiveData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content unarchived and restored to profile'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showUnarchiveDialog(String type, String contentId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Restore to Profile?'),
        content: const Text('This content will be visible on your profile again.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () {
              Navigator.pop(context);
              _unarchive(type, contentId);
            },
            child: const Text('Restore'),
          ),
        ],
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
    final displayList = _activeTab == 0 ? _archivedStories : _archivedPosts;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Archive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSegmentedControl<int>(
                    children: const {
                      0: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Stories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Posts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    },
                    groupValue: _activeTab,
                    onValueChanged: (val) {
                      setState(() {
                        _activeTab = val;
                      });
                      _loadArchiveData();
                    },
                    selectedColor: const Color(0xFF0095F6),
                    borderColor: const Color(0xFF0095F6),
                    unselectedColor: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading && displayList.isEmpty
          ? const Center(child: CupertinoActivityIndicator())
          : displayList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.archive, size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _activeTab == 0 ? 'No archived stories' : 'No archived posts',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final String id = item['id'] ?? item['_id'] ?? '';
                    final String type = _activeTab == 0 ? 'story' : 'post';

                    // Get cover media url
                    String? mediaUrl;
                    if (item['media'] != null && item['media'] is List && (item['media'] as List).isNotEmpty) {
                      mediaUrl = item['media'][0]['media_url'] ?? item['media'][0]['mediaUrl'];
                    } else if (item['media_url'] != null) {
                      mediaUrl = item['media_url'];
                    } else if (item['mediaUrl'] != null) {
                      mediaUrl = item['mediaUrl'];
                    } else if (item['imageUrls'] != null && item['imageUrls'] is List && (item['imageUrls'] as List).isNotEmpty) {
                      mediaUrl = item['imageUrls'][0];
                    }

                    return GestureDetector(
                      onLongPress: () => _showUnarchiveDialog(type, id),
                      child: Container(
                        color: Colors.grey[850],
                        child: mediaUrl != null
                            ? Image.network(mediaUrl, fit: BoxFit.cover)
                            : Center(
                                child: Icon(
                                  _activeTab == 0 ? LucideIcons.circle_play : LucideIcons.image,
                                  color: Colors.white60,
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
