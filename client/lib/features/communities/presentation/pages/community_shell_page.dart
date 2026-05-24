import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';
import 'package:instagram_client/features/communities/presentation/widgets/community_post_card.dart';
import 'package:instagram_client/features/communities/presentation/pages/community_post_create_sheet.dart';
import '../../data/models/community.dart';
import '../../data/models/community_channel.dart';
import '../../data/models/community_post.dart';
import '../providers/community_providers.dart';

class CommunityShellPage extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityShellPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityShellPage> createState() => _CommunityShellPageState();
}

class _CommunityShellPageState extends ConsumerState<CommunityShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CommunityChannel? _selectedChannel;
  bool _isAdminOrMod = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    // Fetch Details & Channels
    final detailsAsync = ref.watch(communityDetailsProvider(widget.communityId));
    final channelsAsync = ref.watch(channelsProvider(widget.communityId));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.menu, color: isDark ? Colors.white : Colors.black),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: detailsAsync.when(
          data: (data) {
            final community = data['community'] as Community;
            final role = data['role'] as String?;
            _isAdminOrMod = ['owner', 'admin', 'moderator'].contains(role);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _selectedChannel != null ? '#${_selectedChannel!.name}' : 'Select a channel',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          // Post Creator Floating/Appbar Trigger
          if (_selectedChannel != null &&
              (!(_selectedChannel!.type == 'announcement') || _isAdminOrMod))
            IconButton(
              icon: Icon(LucideIcons.circle_plus, color: isDark ? Colors.white : Colors.black),
              onPressed: () => _openPostCreator(context),
            ),
          IconButton(
            icon: Icon(LucideIcons.x, color: isDark ? Colors.white : Colors.black),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      drawer: _buildChannelsDrawer(context, channelsAsync, detailsAsync),
      body: _selectedChannel == null
          ? _buildSelectChannelPrompt(isDark, channelsAsync)
          : _buildPostsFeed(currentUserId),
    );
  }

  // ─── POSTS FEED VIEW ─────────────────────────────────────────
  Widget _buildPostsFeed(String currentUserId) {
    final params = CommunityFeedParams(
      communityId: widget.communityId,
      channelId: _selectedChannel!.id,
    );
    final feedAsync = ref.watch(communityFeedProvider(params));

    return feedAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.message_square_dashed, size: 48, color: Colors.white24),
                const SizedBox(height: 12),
                Text(
                  'No posts inside #${_selectedChannel!.name} yet',
                  style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(communityFeedProvider(params).notifier).fetch(),
          color: Colors.white,
          backgroundColor: const Color(0xFF1C1C1E),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return CommunityPostCard(
                post: post,
                currentUserId: currentUserId,
                isAdminOrMod: _isAdminOrMod,
                onLike: () {
                  ref.read(communityFeedProvider(params).notifier).toggleLike(post.id, currentUserId);
                },
                onPin: () {
                  ref.read(communityFeedProvider(params).notifier).togglePin(post.id);
                },
                onDelete: () {
                  ref.read(communityFeedProvider(params).notifier).delete(post.id);
                },
                onVote: (optIdx) {
                  ref.read(communityFeedProvider(params).notifier).vote(post.id, optIdx, currentUserId);
                },
                onRSVP: () {
                  ref.read(communityFeedProvider(params).notifier).rsvp(post.id, currentUserId);
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, __) => Center(
        child: Text(
          'Failed to load posts: $err',
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  // ─── CHANNELS DRAWER SIDEBAR ────────────────────────────────
  Widget _buildChannelsDrawer(
    BuildContext context,
    AsyncValue<List<CommunityChannel>> channelsAsync,
    AsyncValue<Map<String, dynamic>> detailsAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            detailsAsync.when(
              data: (data) {
                final community = data['community'] as Community;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: community.avatarUrl != null && community.avatarUrl!.isNotEmpty
                            ? NetworkImage(community.avatarUrl!)
                            : null,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                        child: community.avatarUrl == null || community.avatarUrl!.isEmpty
                            ? const Icon(LucideIcons.users, color: Colors.white54, size: 22)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${community.handle}',
                              style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox(height: 80),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Channels List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHANNELS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (_isAdminOrMod)
                    IconButton(
                      icon: Icon(LucideIcons.plus, color: isDark ? Colors.white54 : Colors.black54, size: 16),
                      onPressed: () => _showCreateChannelSheet(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Channels List
            Expanded(
              child: channelsAsync.when(
                data: (channels) {
                  // Select first channel by default if none selected
                  if (_selectedChannel == null && channels.isNotEmpty) {
                    Future.microtask(() {
                      setState(() => _selectedChannel = channels.first);
                    });
                  }

                  return ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      final isSelected = _selectedChannel?.id == channel.id;

                      IconData icon = LucideIcons.hash;
                      if (channel.type == 'announcement') icon = LucideIcons.megaphone;
                      else if (channel.type == 'media') icon = LucideIcons.image;
                      else if (channel.type == 'event') icon = LucideIcons.calendar;

                      return ListTile(
                        leading: Icon(
                          icon,
                          color: isSelected ? const Color(0xFFFD1D1D) : Colors.white60,
                          size: 18,
                        ),
                        title: Text(
                          channel.name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFD1D1D) : Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        selected: isSelected,
                        dense: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedChannel = channel);
                          context.pop(); // Close drawer
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
                error: (err, __) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading channels: $err', style: const TextStyle(color: Colors.white38)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectChannelPrompt(bool isDark, AsyncValue<List<CommunityChannel>> channelsAsync) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.hash, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Welcome to the Community!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a channel from the menu to start viewing posts.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD1D1D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            child: const Text('Open Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openPostCreator(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommunityPostCreateSheet(
        onSubmit: (content, type, poll, event, mediaPaths) {
          final params = CommunityFeedParams(
            communityId: widget.communityId,
            channelId: _selectedChannel!.id,
          );
          ref.read(communityFeedProvider(params).notifier).addPost(
                content: content,
                type: type,
                poll: poll,
                event: event,
                mediaPaths: mediaPaths,
              );
        },
      ),
    );
  }

  void _showCreateChannelSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    String selectedType = 'text';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create Channel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Channel name',
                        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                        prefixIcon: Icon(LucideIcons.hash, color: isDark ? Colors.white54 : Colors.black54),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                        DropdownMenuItem(value: 'media', child: Text('Media')),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFD1D1D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        HapticFeedback.lightImpact();
                        try {
                          await ref.read(communityRepositoryProvider).createChannel(
                            widget.communityId,
                            name: nameCtrl.text.trim().toLowerCase().replaceAll(' ', '-'),
                            type: selectedType,
                          );
                          if (context.mounted) {
                            Navigator.pop(context); // Close sheet
                            ref.invalidate(channelsProvider(widget.communityId)); // Refresh channels
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: const Text('Create', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
