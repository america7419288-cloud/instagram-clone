import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:ui';

class GroupInfoSheet extends StatefulWidget {
  final String conversationId;
  final String groupName;
  final String? groupAvatar;
  final List<Map<String, dynamic>> mockMembers; // For premium mock interactions

  const GroupInfoSheet({
    super.key,
    required this.conversationId,
    required this.groupName,
    this.groupAvatar,
    required this.mockMembers,
  });

  static void show(
    BuildContext context, {
    required String conversationId,
    required String groupName,
    String? groupAvatar,
  }) {
    // Generate mock members with nicknames & roles
    final List<Map<String, dynamic>> members = [
      {
        'id': 'me',
        'username': 'ankit',
        'fullName': 'Ankit (You)',
        'role': 'owner',
        'nickname': 'Chief Dev',
        'avatar': 'https://i.pravatar.cc/150?img=12',
      },
      {
        'id': 'user2',
        'username': 'johndoe',
        'fullName': 'John Doe',
        'role': 'admin',
        'nickname': 'Code Master',
        'avatar': 'https://i.pravatar.cc/150?img=22',
      },
      {
        'id': 'user3',
        'username': 'sarah_k',
        'fullName': 'Sarah Koenig',
        'role': 'member',
        'nickname': 'Designer',
        'avatar': 'https://i.pravatar.cc/150?img=32',
      },
      {
        'id': 'user4',
        'username': 'alex_coder',
        'fullName': 'Alex Rivera',
        'role': 'member',
        'nickname': 'Bug Hunter',
        'avatar': 'https://i.pravatar.cc/150?img=42',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupInfoSheet(
        conversationId: conversationId,
        groupName: groupName,
        groupAvatar: groupAvatar,
        mockMembers: members,
      ),
    );
  }

  @override
  State<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<GroupInfoSheet> {
  late List<Map<String, dynamic>> _members;
  bool _isMuted = false;
  String _disappearingDuration = 'Off';
  bool _onlyAdminsCanSend = false;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.mockMembers);
  }

  void _muteGroup() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mute Notifications',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...['1 Hour', '8 Hours', '24 Hours', 'Until I turn it back on'].map((duration) {
                return ListTile(
                  title: Text(duration, style: const TextStyle(color: Colors.white70)),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isMuted = true);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _editNickname(int index) {
    final TextEditingController ctrl = TextEditingController(text: _members[index]['nickname'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Set Nickname', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter nickname...',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFD1D1D))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _members[index]['nickname'] = ctrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFFD1D1D))),
          ),
        ],
      ),
    );
  }

  void _changeRole(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Change Member Role', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...['admin', 'moderator', 'member'].map((role) {
                return ListTile(
                  title: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _members[index]['role'] = role;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.82) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, safeBot + 16),
        child: Column(
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
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
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: widget.groupAvatar != null ? NetworkImage(widget.groupAvatar!) : null,
                      backgroundColor: Colors.white10,
                      child: widget.groupAvatar == null
                          ? const Icon(LucideIcons.users, color: Colors.white70, size: 36)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.groupName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Group Chat • 4 members',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Actions Tiles Group
                    _buildSettingsSection(isDark),
                    const SizedBox(height: 24),

                    // Pinned Messages Section
                    _buildPinnedMessagesSection(isDark),
                    const SizedBox(height: 24),

                    // Members List
                    _buildMembersSection(isDark),
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
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(_isMuted ? LucideIcons.bell_off : LucideIcons.bell, size: 20),
            title: const Text('Mute Notifications'),
            trailing: Text(
              _isMuted ? 'Muted' : 'Off',
              style: TextStyle(color: _isMuted ? const Color(0xFFFD1D1D) : Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onTap: _muteGroup,
          ),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: const Icon(LucideIcons.message_square_dashed, size: 20),
            title: const Text('Disappearing Messages'),
            trailing: Text(
              _disappearingDuration,
              style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _disappearingDuration = _disappearingDuration == 'Off' ? '24 Hours' : 'Off';
              });
            },
          ),
          const Divider(color: Colors.white10, height: 1),
          SwitchListTile(
            secondary: const Icon(LucideIcons.shield_check, size: 20),
            title: const Text('Only Admins Can Send'),
            value: _onlyAdminsCanSend,
            activeColor: const Color(0xFFFD1D1D),
            onChanged: (val) {
              HapticFeedback.mediumImpact();
              setState(() => _onlyAdminsCanSend = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessagesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'PINNED MESSAGES (UP TO 3)',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            leading: const Icon(LucideIcons.pin, color: Color(0xFFFD1D1D), size: 18),
            title: const Text('Welcome developers to the team!', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            subtitle: const Text('Pinned by chief_dev • 2h ago', style: TextStyle(fontSize: 11, color: Colors.white38)),
            trailing: IconButton(
              icon: const Icon(LucideIcons.x, size: 14, color: Colors.white38),
              onPressed: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GROUP MEMBERS',
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Icon(LucideIcons.circle_plus, size: 14, color: Color(0xFFFD1D1D)),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Color(0xFFFD1D1D), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final member = _members[index];
              final role = member['role'] as String;
              final nickname = member['nickname'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(member['avatar']),
                ),
                title: Row(
                  children: [
                    Text(member['username'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: role == 'owner' || role == 'admin' ? const Color(0xFFFD1D1D).withOpacity(0.12) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          color: role == 'owner' || role == 'admin' ? const Color(0xFFFD1D1D) : Colors.white60,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  nickname != null && nickname.isNotEmpty ? 'Nickname: $nickname' : member['fullName'],
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 14, color: Colors.white38),
                      onPressed: () => _editNickname(index),
                    ),
                    if (member['id'] != 'me')
                      IconButton(
                        icon: const Icon(LucideIcons.shield, size: 14, color: Colors.white38),
                        onPressed: () => _changeRole(index),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
