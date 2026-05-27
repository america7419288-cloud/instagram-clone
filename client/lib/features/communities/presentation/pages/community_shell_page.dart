import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';
import 'package:instagram_client/features/communities/presentation/widgets/community_post_card.dart';
import 'package:instagram_client/features/communities/presentation/pages/community_post_create_sheet.dart';
import '../../data/models/community.dart';
import '../../data/models/community_channel.dart';
import '../providers/community_providers.dart';
import '../../../../shared/widgets/mention_text_field.dart';

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
  bool _isEditingChannels = false;
  final Set<String> _selectedChannelIds = {};
  final MentionTextFieldController _chatCtrl = MentionTextFieldController();

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final params = CommunityFeedParams(
      communityId: widget.communityId,
      channelId: _selectedChannel!.id,
    );
    final feedAsync = ref.watch(communityFeedProvider(params));
    final canWrite = !(_selectedChannel!.type == 'announcement') || _isAdminOrMod;

    return Column(
      children: [
        Expanded(
          child: feedAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.message_square_dashed, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        'No messages inside #${_selectedChannel!.name} yet',
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(communityFeedProvider(params).notifier).fetch(),
                color: isDark ? Colors.white : const Color(0xFFFD1D1D),
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                child: ListView.builder(
                  reverse: true,
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
            loading: () => Center(child: CircularProgressIndicator(color: isDark ? Colors.white : const Color(0xFFFD1D1D))),
            error: (err, __) => Center(
              child: Text(
                'Failed to load posts: $err',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ),
        ),
        if (canWrite) _buildChatComposer(params),
      ],
    );
  }

  Widget _buildChatComposer(CommunityFeedParams params) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(LucideIcons.circle_plus, color: isDark ? Colors.white70 : Colors.black87),
              onPressed: () => _openPostCreator(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MentionTextField(
                  controller: _chatCtrl,
                  contextType: 'community',
                  contextId: widget.communityId,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message #${_selectedChannel?.name ?? ""}',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChatMessage(params),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendChatMessage(params),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                  ),
                ),
                child: const Icon(LucideIcons.send, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendChatMessage(CommunityFeedParams params) {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(communityFeedProvider(params).notifier).addPost(
          content: text,
          type: 'text',
        );
    _chatCtrl.clear();
  }

  Future<void> _pickAndUploadAvatar(String communityId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    HapticFeedback.mediumImpact();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading community avatar...')),
    );

    try {
      await ref.read(communityRepositoryProvider).updateAvatar(communityId, image.path);
      ref.invalidate(communityDetailsProvider(communityId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    }
  }

  Future<void> _bulkDeleteChannels(BuildContext context) async {
    final count = _selectedChannelIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: const Text('Delete Channels', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete $count channel(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFD1D1D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.mediumImpact();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleting channels...')),
    );

    try {
      final repo = ref.read(communityRepositoryProvider);
      
      for (final id in _selectedChannelIds) {
        await repo.deleteChannel(widget.communityId, id);
      }

      final wasCurrentDeleted = _selectedChannelIds.contains(_selectedChannel?.id);
      ref.invalidate(channelsProvider(widget.communityId));

      if (wasCurrentDeleted) {
        setState(() {
          _selectedChannel = null;
        });
      }

      setState(() {
        _isEditingChannels = false;
        _selectedChannelIds.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Channels deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete channels: $e')),
      );
    }
  }

  // ─── CHANNELS DRAWER SIDEBAR ────────────────────────────────
  Widget _buildChannelsDrawer(
    BuildContext context,
    AsyncValue<List<CommunityChannel>> channelsAsync,
    AsyncValue<Map<String, dynamic>> detailsAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBgColor = isDark ? Colors.black.withOpacity(0.72) : Colors.white.withOpacity(0.85);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white54 : Colors.black54;
    final captionColor = isDark ? Colors.white38 : Colors.black45;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: drawerBgColor,
              border: Border(right: BorderSide(color: borderColor, width: 0.5)),
            ),
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
                            GestureDetector(
                              onTap: _isAdminOrMod ? () => _pickAndUploadAvatar(community.id) : null,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: community.avatarUrl != null && community.avatarUrl!.isNotEmpty
                                        ? NetworkImage(community.avatarUrl!)
                                        : null,
                                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                    child: community.avatarUrl == null || community.avatarUrl!.isEmpty
                                        ? Icon(LucideIcons.users, color: subtextColor, size: 22)
                                        : null,
                                  ),
                                  if (_isAdminOrMod)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFD1D1D),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(LucideIcons.camera, color: Colors.white, size: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community.name,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '@${community.handle}',
                                        style: TextStyle(fontSize: 12, color: captionColor, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(LucideIcons.users, size: 10, color: captionColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${community.memberCount}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                  Divider(color: borderColor, height: 1),

                  // Channels List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'CHANNELS',
                          style: TextStyle(
                            color: captionColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        if (_isAdminOrMod) ...[
                          if (_isEditingChannels) ...[
                            IconButton(
                              icon: Icon(
                                LucideIcons.trash_2,
                                color: _selectedChannelIds.isNotEmpty ? const Color(0xFFFD1D1D) : captionColor,
                                size: 16,
                              ),
                              onPressed: _selectedChannelIds.isNotEmpty ? () => _bulkDeleteChannels(context) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(LucideIcons.check, color: subtextColor, size: 16),
                              onPressed: () {
                                setState(() {
                                  _isEditingChannels = false;
                                  _selectedChannelIds.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ] else ...[
                            IconButton(
                              icon: Icon(LucideIcons.pencil, color: subtextColor, size: 16),
                              onPressed: () {
                                setState(() {
                                  _isEditingChannels = true;
                                  _selectedChannelIds.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(LucideIcons.plus, color: subtextColor, size: 16),
                              onPressed: () => _showCreateChannelSheet(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            final isSelected = _selectedChannel?.id == channel.id;
                            final isChecked = _selectedChannelIds.contains(channel.id);

                            IconData icon = LucideIcons.hash;
                            if (channel.type == 'announcement') icon = LucideIcons.megaphone;
                            else if (channel.type == 'media') icon = LucideIcons.image;
                            else if (channel.type == 'event') icon = LucideIcons.calendar;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                leading: Icon(
                                  icon,
                                  color: isSelected ? const Color(0xFFFD1D1D) : subtextColor,
                                  size: 18,
                                ),
                                title: Text(
                                  channel.name,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFFFD1D1D) : textColor,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                dense: true,
                                trailing: _isEditingChannels && !channel.isDefault
                                    ? Checkbox(
                                        activeColor: const Color(0xFFFD1D1D),
                                        value: isChecked,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedChannelIds.add(channel.id);
                                            } else {
                                              _selectedChannelIds.remove(channel.id);
                                            }
                                          });
                                        },
                                      )
                                    : null,
                                onTap: _isEditingChannels
                                    ? (channel.isDefault
                                        ? null
                                        : () {
                                            setState(() {
                                              if (isChecked) {
                                                _selectedChannelIds.remove(channel.id);
                                              } else {
                                                _selectedChannelIds.add(channel.id);
                                              }
                                            });
                                          })
                                    : () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _selectedChannel = channel);
                                        context.pop(); // Close drawer
                                      },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => Center(child: CircularProgressIndicator(color: isDark ? Colors.white24 : Colors.black26)),
                      error: (err, __) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading channels: $err', style: TextStyle(color: captionColor)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectChannelPrompt(bool isDark, AsyncValue<List<CommunityChannel>> channelsAsync) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.hash, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'Welcome to the Community!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a channel from the menu to start viewing posts.',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
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
