import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/saved_collection_model.dart';

class SavedPostsPage extends ConsumerStatefulWidget {
  const SavedPostsPage({super.key});

  @override
  ConsumerState<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends ConsumerState<SavedPostsPage> {
  List<SavedCollectionModel> _collections = [];
  List<dynamic> _savedPosts = [];
  bool _isLoading = false;
  SavedCollectionModel? _activeCollection;

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _loadSavedPosts();
  }

  Future<void> _loadCollections() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getCollections();
      setState(() {
        _collections = list;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final list = await repo.getSavedPosts(collectionId: _activeCollection?.id);
      setState(() {
        _savedPosts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _createCollection() async {
    final nameController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Collection'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Collection Name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Create'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                try {
                  final repo = ref.read(settingsRepositoryProvider);
                  await repo.createCollection(name);
                  _loadCollections();
                } catch (e) {
                  _showError(e.toString());
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollection(String id) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.deleteCollection(id);
      setState(() {
        _activeCollection = null;
      });
      _loadCollections();
      _loadSavedPosts();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _organizePost(dynamic post) async {
    final repo = ref.read(settingsRepositoryProvider);
    final postId = post['id'] ?? post['_id'];
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Organize Saved Post'),
        actions: [
          ..._collections.map((col) => CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await repo.addToCollection(col.id, postId);
                _loadSavedPosts();
                _loadCollections();
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: Text(col.name),
          )),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await repo.unsavePost(postId);
                _loadSavedPosts();
                _loadCollections();
              } catch (e) {
                _showError(e.toString());
              }
            },
            isDestructiveAction: true,
            child: const Text('Unsave Post'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
        title: Text(_activeCollection != null ? _activeCollection!.name : 'Saved Posts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: _activeCollection != null
            ? IconButton(
                icon: const Icon(CupertinoIcons.back),
                onPressed: () {
                  setState(() {
                    _activeCollection = null;
                  });
                  _loadSavedPosts();
                },
              )
            : null,
        actions: [
          if (_activeCollection == null)
            IconButton(
              icon: const Icon(CupertinoIcons.add),
              onPressed: _createCollection,
            )
          else
            IconButton(
              icon: const Icon(CupertinoIcons.ellipsis),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    title: Text('Manage ${_activeCollection!.name}'),
                    actions: [
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteCollection(_activeCollection!.id);
                        },
                        isDestructiveAction: true,
                        child: const Text('Delete Collection'),
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_activeCollection == null && _collections.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Collections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_collections.length} folders', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _collections.length,
                itemBuilder: (context, index) {
                  final col = _collections[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeCollection = col;
                      });
                      _loadSavedPosts();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 90,
                      child: Column(
                        children: [
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Icon(LucideIcons.folder, color: Colors.blue, size: 28),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            col.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
          ],
          if (_isLoading && _savedPosts.isEmpty)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))
          else if (_savedPosts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.bookmark, size: 64, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved posts yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Posts you bookmark will appear here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                itemCount: _savedPosts.length,
                itemBuilder: (context, index) {
                  final item = _savedPosts[index];

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
                    onTap: () => _organizePost(item),
                    child: Container(
                      color: Colors.grey[850],
                      child: mediaUrl != null
                          ? Image.network(mediaUrl, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(
                                LucideIcons.image,
                                color: Colors.white60,
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
