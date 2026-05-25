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
import '../../../chat/data/models/chat_user.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';

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

  // Shows a bottom sheet for managing a specific member (role change + remove)
  void _showMemberActions(Conversation conversation, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.white54 : Colors.black54;
    final member = conversation.participants[index];
    final currentUser = ref.read(currentUserProvider);
    final isOwner = conversation.createdBy == currentUser?.id;
    final isSelf = member.id == currentUser?.id;
    if (isSelf) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '@${member.username}',
                  style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  member.role.toUpperCase(),
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
                const SizedBox(height: 20),
                // Change Role (admins & owners)
                ListTile(
                  leading: Icon(LucideIcons.shield, color: const Color(0xFF0095F6), size: 20),
                  title: Text('Change Role', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text('Make admin or set as member', style: TextStyle(color: mutedColor, fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeRole(conversation, index);
                  },
                ),
                const Divider(height: 1),
                // Remove member (owners can remove anyone; admins can only remove non-admins)
                if (isOwner || member.role != 'admin')
                  ListTile(
                    leading: const Icon(LucideIcons.user_minus, color: Color(0xFFFD1D1D), size: 20),
                    title: const Text('Remove from Group', style: TextStyle(color: Color(0xFFFD1D1D), fontWeight: FontWeight.w600)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      Navigator.pop(ctx);
                      HapticFeedback.heavyImpact();
                      await ref.read(chatProvider(conversation.id).notifier).removeGroupMember(member.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Shows only role change options
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

    final currentUser = ref.watch(currentUserProvider);
    final isOwner = conversation.createdBy == currentUser?.id;
    final currentMember = conversation.participants.where((p) => p.id == currentUser?.id).firstOrNull;
    final isAdmin = currentMember?.role == 'admin';
    final canManageSettings = isOwner || isAdmin;

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
                      onTap: canManageSettings ? () => _pickAvatar(conversation) : null,
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
                          if (canManageSettings)
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
                    _buildSettingsSection(conversation, isDark, textColor, mutedColor, dividerColor, cardBg, canManageSettings),
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
                        _handleLeaveGroup(conversation);
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

  Widget _buildSettingsSection(Conversation conversation, bool isDark, Color textColor, Color mutedColor, Color dividerColor, Color cardBg, bool canManageSettings) {
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
          if (canManageSettings) ...[
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
        ],
      ),
    );
  }

  void _handleLeaveGroup(Conversation conversation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);
    final isOwner = conversation.createdBy == currentUser?.id;
    final otherMembers = conversation.participants
        .where((p) => p.id != currentUser?.id)
        .toList();

    if (isOwner && otherMembers.isNotEmpty) {
      // Owner must transfer ownership before leaving
      _showTransferOwnershipSheet(conversation, otherMembers, isDark);
      return;
    }

    // Regular member or owner with no other members — just confirm and leave
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.log_out, color: const Color(0xFFFD1D1D), size: 36),
                const SizedBox(height: 12),
                Text(
                  'Leave Group?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will no longer be able to send or receive messages in this group.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        ),
                        child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          Navigator.pop(context); // close group info sheet
                          await ref.read(inboxProvider.notifier).deleteConversation(conversation.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD1D1D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransferOwnershipSheet(
    Conversation conversation,
    List<ChatUser> candidates,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.white54 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      children: [
                        Icon(LucideIcons.crown, color: const Color(0xFFFFC107), size: 32),
                        const SizedBox(height: 10),
                        Text(
                          'Transfer Ownership',
                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose a member to become the new group owner before you leave.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: dividerColor, height: 24),
                  // Member list
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => Divider(color: dividerColor, height: 1),
                      itemBuilder: (_, i) {
                        final candidate = candidates[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: candidate.profilePicUrl != null
                                ? NetworkImage(candidate.profilePicUrl!)
                                : null,
                            backgroundColor: dividerColor,
                            child: candidate.profilePicUrl == null
                                ? Icon(LucideIcons.user, size: 18, color: mutedColor)
                                : null,
                          ),
                          title: Text(
                            candidate.username,
                            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                          ),
                          subtitle: Text(
                            candidate.role.toUpperCase(),
                            style: TextStyle(fontSize: 11, color: mutedColor),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              HapticFeedback.mediumImpact();
                              // 1. Transfer ownership
                              await ref
                                  .read(chatProvider(conversation.id).notifier)
                                  .transferGroupOwnership(candidate.id);
                              if (!mounted) return;
                              // 2. Leave the group
                              Navigator.pop(context); // close group info sheet
                              await ref
                                  .read(inboxProvider.notifier)
                                  .deleteConversation(conversation.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFD1D1D),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Select', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                  ),
                  // Cancel button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: dividerColor),
                        ),
                        child: Text('Cancel', style: TextStyle(color: textColor)),
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

  Widget _buildMembersSection(Conversation conversation, bool isDark, Color textColor, Color mutedColor, Color dividerColor, Color cardBg) {
      final currentUser = ref.watch(currentUserProvider);
    final currentMember = conversation.participants.firstWhere(
      (p) => p.id == currentUser?.id,
      orElse: () => ChatUser(id: '', username: '', role: 'member'),
    );
    final isCurrentUserAdmin = currentMember.role == 'admin';
    final isCurrentUserOwner = conversation.createdBy == currentUser?.id;
    final canManageMembers = isCurrentUserAdmin || isCurrentUserOwner;

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
              final isSelf = member.id == currentUser?.id;
              final isTargetOwner = conversation.createdBy == member.id;
              // Show manage button: if current user can manage AND it's not themselves
              // AND (owner can manage anyone, admin can manage non-admins/non-owners)
              final showManageButton = canManageMembers &&
                  !isSelf &&
                  !isTargetOwner &&
                  (isCurrentUserOwner || member.role != 'admin');
              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
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
                    Navigator.pop(context);
                    context.push('/profile/${Uri.encodeComponent(member.username)}');
                  },
                  child: Text(member.username, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                ),
                subtitle: Text(
                  '${member.fullName ?? ''}${member.fullName != null && member.fullName!.isNotEmpty ? ' \u2022 ' : ''}${isTargetOwner ? 'OWNER' : member.role.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: mutedColor),
                ),
                trailing: showManageButton
                    ? IconButton(
                        icon: Icon(LucideIcons.settings_2, size: 16, color: mutedColor),
                        onPressed: () => _showMemberActions(conversation, index),
                      )
                    : null,
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

