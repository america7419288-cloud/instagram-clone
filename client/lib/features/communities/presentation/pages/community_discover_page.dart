import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_client/features/communities/presentation/pages/community_shell_page.dart';
import 'package:instagram_client/features/communities/presentation/pages/community_create_sheet.dart';
import '../../data/models/community.dart';
import '../providers/community_providers.dart';

class CommunityDiscoverPage extends ConsumerStatefulWidget {
  const CommunityDiscoverPage({super.key});

  @override
  ConsumerState<CommunityDiscoverPage> createState() => _CommunityDiscoverPageState();
}

class _CommunityDiscoverPageState extends ConsumerState<CommunityDiscoverPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<String> _categories = [
    'all',
    'tech',
    'gaming',
    'music',
    'sports',
    'art',
    'fashion',
    'fitness',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fetch lists
    final myAsync = ref.watch(myCommunitiesProvider);
    final discoverAsync = ref.watch(discoverCommunitiesProvider(_selectedCategory));
    final searchAsync = ref.watch(searchCommunitiesProvider(_searchQuery));

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Communities',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.circle_plus, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _openCreateSheet(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search communities by name or handle...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(LucideIcons.x, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                ],
              ),
            ),
          ),

          // Categorized filters if not searching
          if (_searchQuery.isEmpty) ...[
            SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          letterSpacing: 0.5,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFD1D1D),
                      backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],

          // Dynamic Feed View
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchFeed(isDark, searchAsync)
                : _buildDiscoverAndMyFeed(isDark, myAsync, discoverAsync),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH FEED ─────────────────────────────────────────────
  Widget _buildSearchFeed(bool isDark, AsyncValue<List<Community>> searchAsync) {
    return searchAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('No matching communities found.', style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          itemBuilder: (context, idx) {
            final c = list[idx];
            return _buildCommunityRow(isDark, c);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
      error: (err, __) => Center(child: Text('Error: $err')),
    );
  }

  // ─── MAIN FEED: MY + DISCOVER ────────────────────────────────
  Widget _buildDiscoverAndMyFeed(
    bool isDark,
    AsyncValue<List<Community>> myAsync,
    AsyncValue<List<Community>> discoverAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(myCommunitiesProvider.notifier).refresh();
        ref.invalidate(discoverCommunitiesProvider(_selectedCategory));
      },
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1E),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Joined/My Communities Header
          myAsync.when(
            data: (joined) {
              if (joined.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text(
                        'MY COMMUNITIES',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: joined.length,
                        itemBuilder: (context, index) {
                          final c = joined[index];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommunityShellPage(communityId: c.id),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                                        ? NetworkImage(c.avatarUrl!)
                                        : null,
                                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                                    child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                                        ? const Icon(LucideIcons.users, color: Colors.white54)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 20),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 100)),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Discoverable Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'DISCOVER NEW COMMUNITIES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),

          // Discoverable List
          discoverAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No communities matching this category yet.', style: TextStyle(color: Colors.white38)),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    final c = list[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCommunityRow(isDark, c),
                    );
                  },
                  childCount: list.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.white24)),
            ),
            error: (err, __) => SliverFillRemaining(
              child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityRow(bool isDark, Community c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                ? NetworkImage(c.avatarUrl!)
                : null,
            backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
            child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                ? const Icon(LucideIcons.users, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (c.privacy == 'private')
                      Icon(LucideIcons.lock, size: 12, color: isDark ? Colors.white38 : Colors.black38)
                    else
                      Icon(LucideIcons.globe, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${c.handle} • ${c.memberCount} members',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
                ),
                if (c.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    c.description,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final myCommunities = ref.read(myCommunitiesProvider).value ?? [];
              final isMember = myCommunities.any((x) => x.id == c.id);

              if (isMember) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CommunityShellPage(communityId: c.id)),
                );
              } else {
                // Trigger direct join for public
                try {
                  final result = await ref.read(myCommunitiesProvider.notifier).joinViaInvite(c.inviteLink ?? c.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CommunityShellPage(communityId: result)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to join: $e')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Join',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CommunityCreateSheet(),
    );
  }
}
