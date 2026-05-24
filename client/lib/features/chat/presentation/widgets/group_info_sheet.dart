import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_notifiers.dart';
import '../../../search/presentation/pages/providers/search_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../../chat/data/models/conversation.dart';

class GroupInfoSheet extends ConsumerStatefulWidget {
  final Conversation conversation;

  const GroupInfoSheet({
    super.key,
    required this.conversation,
  });

  static void show(
    BuildContext context, {
    required Conversation conversation,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupInfoSheet(
        conversation: conversation,
      ),
    );
  }

  @override
  ConsumerState<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<GroupInfoSheet> {
  String? _localAvatarPath;

  String _getDisappearingLabel(int? duration) {
    if (duration == null || duration == 0) return 'Off';
    if (duration <= 86400) return '24 Hours';
    if (duration <= 604800) return '7 Days';
    return '90 Days';
  }

  void _muteGroup(Conversation conversation) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mute Notifications',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...['1 Hour', '8 Hours', '24 Hours', 'Until I turn it back on'].map((duration) {
                return ListTile(
                  title: Text(duration, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final map = {
                      '1 Hour': '1h',
                      '8 Hours': '8h',
                      '24 Hours': '24h',
                      'Until I turn it back on': 'forever'
                    };
                    ref.read(inboxProvider.notifier).muteConversation(conversation.id, map[duration]!);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _changeRole(Conversation conversation, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Change Member Role', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...['admin', 'member'].map((role) {
                return ListTile(
                  title: Text(role.toUpperCase(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13)),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    final member = conversation.participants[index];
                    await ref.read(chatProvider(conversation.id).notifier).updateGroupMemberRole(member.id, role);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    ),
    );
  }
  
  Future<void> _pickAvatar(Conversation conversation) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      HapticFeedback.mediumImpact();
      setState(() {
         _localAvatarPath = pickedFile.path;
      });
      await ref.read(chatProvider(conversation.id).notifier).updateGroupSettings(avatarPath: pickedFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group avatar updated!')));
      }
    }
  }

  void _addParticipant(Conversation conversation) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddParticipantSheet(
        conversationId: conversation.id,
        onAdd: (userId) async {
          await ref.read(chatProvider(conversation.id).notifier).addGroupMembers([userId]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;
    
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.white54 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02);

    // Watch dynamic conversation
    final inboxState = ref.watch(inboxProvider);
    final conversation = inboxState.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => inboxState.requests.firstWhere(
        (c) => c.id == widget.conversation.id,
        orElse: () => widget.conversation,
      ),
    );

    final avatarProvider = _localAvatarPath != null 
        ? FileImage(File(_localAvatarPath!)) 
        : (conversation.avatarUrl != null ? NetworkImage(conversation.avatarUrl!) : null);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.82) : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: dividerColor),
          ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, safeBot + 16),
        child: Column(
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 20, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Group Avatar & Name
                    GestureDetector(
                      onTap: () => _pickAvatar(conversation),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: avatarProvider as ImageProvider?,
                            backgroundColor: dividerColor,
                            child: avatarProvider == null
                                ? Icon(LucideIcons.users, color: mutedColor, size: 36)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFD1D1D),
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                            ),
                            child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      conversation.name ?? 'Group Chat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Group Chat • ${conversation.participants.length} members',
                      style: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Actions Tiles Group
                    _buildSettingsSection(conversation, isDark, textColor, mutedColor, dividerColor, cardBg),
                    const SizedBox(height: 24),

                    // Members List
                    _buildMembersSection(conversation, isDark, textColor, mutedColor, dividerColor, cardBg),
                    const SizedBox(height: 24),

                    // Leave/Delete Group
                    ListTile(
                      leading: const Icon(LucideIcons.log_out, color: Color(0xFFFD1D1D)),
                      title: const Text('Leave Group', style: TextStyle(color: Color(0xFFFD1D1D), fontWeight: FontWeight.bold)),
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSettingsSection(Conversation conversation, bool isDark, Color textColor, Color mutedColor, Color dividerColor, Color cardBg) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(conversation.isMuted ? LucideIcons.bell_off : LucideIcons.bell, size: 20, color: textColor),
            title: Text('Mute Notifications', style: TextStyle(color: textColor)),
            trailing: Text(
              conversation.isMuted ? 'Muted' : 'Off',
              style: TextStyle(color: conversation.isMuted ? const Color(0xFFFD1D1D) : mutedColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              if (conversation.isMuted) {
                HapticFeedback.mediumImpact();
                ref.read(inboxProvider.notifier).unmuteConversation(conversation.id);
              } else {
                _muteGroup(conversation);
              }
            },
          ),
          Divider(color: dividerColor, height: 1),
          ListTile(
            leading: Icon(LucideIcons.message_square_dashed, size: 20, color: textColor),
            title: Text('Disappearing Messages', style: TextStyle(color: textColor)),
            trailing: Text(
              _getDisappearingLabel(conversation.disappearingDuration),
              style: TextStyle(color: mutedColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              final currentDuration = conversation.disappearingDuration;
              final newDuration = (currentDuration == null || currentDuration == 0) ? 86400 : 0;
              ref.read(chatProvider(conversation.id).notifier).setDisappearingMessages(newDuration);
            },
          ),
          Divider(color: dividerColor, height: 1),
          SwitchListTile(
            secondary: Icon(LucideIcons.shield_check, size: 20, color: textColor),
            title: Text('Only Admins Can Send', style: TextStyle(color: textColor)),
            value: conversation.onlyAdminsCanSend ?? false,
            activeColor: const Color(0xFFFD1D1D),
            onChanged: (val) {
              HapticFeedback.mediumImpact();
              ref.read(chatProvider(conversation.id).notifier).updateGroupSettings(onlyAdminsCanSend: val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(Conversation conversation, bool isDark, Color textColor, Color mutedColor, Color dividerColor, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GROUP MEMBERS',
                style: TextStyle(color: mutedColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
              GestureDetector(
                onTap: () => _addParticipant(conversation),
                child: Row(
                  children: [
                    const Icon(LucideIcons.circle_plus, size: 14, color: Color(0xFFFD1D1D)),
                    const SizedBox(width: 4),
                    const Text('Add', style: TextStyle(color: Color(0xFFFD1D1D), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conversation.participants.length,
            separatorBuilder: (_, __) => Divider(color: dividerColor, height: 1),
            itemBuilder: (context, index) {
              final member = conversation.participants[index];
              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context); // Close modal first
                    context.push('/profile/${Uri.encodeComponent(member.username)}');
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: member.profilePicUrl != null ? NetworkImage(member.profilePicUrl!) : null,
                    backgroundColor: dividerColor,
                    child: member.profilePicUrl == null ? Icon(LucideIcons.user, size: 18, color: mutedColor) : null,
                  ),
                ),
                title: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context); // Close modal first
                    context.push('/profile/${Uri.encodeComponent(member.username)}');
                  },
                  child: Text(member.username, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                ),
                subtitle: Text(
                  '${member.fullName ?? ''}${member.fullName != null && member.fullName!.isNotEmpty ? ' • ' : ''}${member.role.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                trailing: IconButton(
                  icon: Icon(LucideIcons.shield, size: 14, color: mutedColor),
                  onPressed: () => _changeRole(conversation, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddParticipantSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final ValueChanged<String> onAdd;
  const _AddParticipantSheet({required this.conversationId, required this.onAdd});

  @override
  ConsumerState<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends ConsumerState<_AddParticipantSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  void _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _isLoading = false; });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final service = ref.read(searchServiceProvider);
      final res = await service.searchUsers(query: query, excludeConversationId: widget.conversationId);
      if (mounted) setState(() { _results = res['users']; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Participants', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(LucideIcons.x, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                prefixIcon: Icon(LucideIcons.search, color: isDark ? Colors.white30 : Colors.black38, size: 18),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final u = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u['profile_pic_url'] != null ? NetworkImage(u['profile_pic_url']) : null,
                          child: u['profile_pic_url'] == null ? const Icon(LucideIcons.user) : null,
                        ),
                        title: Text(u['username'], style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text(u['full_name'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            widget.onAdd(u['id']);
                            Navigator.pop(context);
                          },
                          child: const Text('Add'),
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

