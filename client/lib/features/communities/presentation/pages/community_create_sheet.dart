import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:ui';
import 'package:instagram_client/features/communities/presentation/pages/community_shell_page.dart';
import '../providers/community_providers.dart';

class CommunityCreateSheet extends ConsumerStatefulWidget {
  const CommunityCreateSheet({super.key});

  @override
  ConsumerState<CommunityCreateSheet> createState() => _CommunityCreateSheetState();
}

class _CommunityCreateSheetState extends ConsumerState<CommunityCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _handleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _category = 'tech';
  String _privacy = 'public';

  static const _categories = [
    {'key': 'tech',          'label': 'Tech',           'emoji': '💻'},
    {'key': 'gaming',        'label': 'Gaming',         'emoji': '🎮'},
    {'key': 'music',         'label': 'Music',          'emoji': '🎵'},
    {'key': 'sports',        'label': 'Sports',         'emoji': '⚽'},
    {'key': 'art',           'label': 'Art',            'emoji': '🎨'},
    {'key': 'fashion',       'label': 'Fashion',        'emoji': '👗'},
    {'key': 'fitness',       'label': 'Fitness',        'emoji': '💪'},
    {'key': 'photography',   'label': 'Photography',    'emoji': '📸'},
    {'key': 'food',          'label': 'Food',           'emoji': '🍕'},
    {'key': 'nature',        'label': 'Nature',         'emoji': '🌿'},
    {'key': 'science',       'label': 'Science',        'emoji': '🚀'},
    {'key': 'education',     'label': 'Education',      'emoji': '📚'},
    {'key': 'business',      'label': 'Business',       'emoji': '💼'},
    {'key': 'entertainment', 'label': 'Entertainment',  'emoji': '🎬'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final handle = _handleCtrl.text.trim();
    final description = _descCtrl.text.trim();

    HapticFeedback.mediumImpact();
    Navigator.pop(context); // Close sheet

    try {
      final community = await ref.read(myCommunitiesProvider.notifier).create(
            name: name,
            handle: handle,
            description: description,
            category: _category,
            privacy: _privacy,
          );

      // Open new community
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CommunityShellPage(communityId: community.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create community: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedColor = isDark ? Colors.white54 : Colors.black54;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.76) : Colors.white.withValues(alpha: 0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, safeBot + 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Community',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
              const SizedBox(height: 16),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Community Name
                      _buildLabel('COMMUNITY NAME', isDark),
                      TextFormField(
                        controller: _nameCtrl,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: _buildInputDecoration('Enter a matching community name', isDark),
                      ),
                      const SizedBox(height: 16),

                      // Community Handle
                      _buildLabel('HANDLE', isDark),
                      TextFormField(
                        controller: _handleCtrl,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Handle is required';
                          if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(v)) {
                            return '3-30 chars, letters, numbers, or underscores only';
                          }
                          return null;
                        },
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: _buildInputDecoration('e.g. flutter_devs', isDark).copyWith(
                          prefixIcon: Icon(LucideIcons.at_sign, size: 16, color: mutedColor),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildLabel('DESCRIPTION', isDark),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: _buildInputDecoration('What is this community about?', isDark),
                      ),
                      const SizedBox(height: 16),

                      // Category — Chip Selector
                      _buildLabel('CATEGORY', isDark),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _category == cat['key'];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _category = cat['key']!);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFD1D1D).withValues(alpha: 0.12)
                                    : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFD1D1D).withValues(alpha: 0.6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(cat['emoji']!, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat['label']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFFFD1D1D)
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Privacy Picker
                      _buildLabel('PRIVACY', isDark),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPrivacyCard('public', 'Public', 'Anyone can search and join directly.', isDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrivacyCard('private', 'Private', 'Requires approved join requests.', isDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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

  Widget _buildLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(String value, String title, String subtitle, bool isDark) {
    final isSelected = _privacy == value;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _privacy = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFD1D1D).withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFD1D1D).withValues(alpha: 0.5)
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  value == 'public' ? LucideIcons.globe : LucideIcons.lock,
                  size: 16,
                  color: isSelected ? const Color(0xFFFD1D1D) : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFFFD1D1D) : textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFFFD1D1D).withValues(alpha: 0.7)
                    : (isDark ? Colors.white38 : Colors.black38),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFD1D1D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFD1D1D)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFD1D1D)),
      ),
    );
  }
}
