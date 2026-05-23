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

  final List<String> _categories = [
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
    final safeBot = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.76,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.76) : Colors.white.withOpacity(0.9),
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
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Community',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Community Name
                      _buildLabel('COMMUNITY NAME'),
                      TextFormField(
                        controller: _nameCtrl,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        style: const TextStyle(fontSize: 14),
                        decoration: _buildInputDecoration('Enter a matching community name', isDark),
                      ),
                      const SizedBox(height: 16),

                      // Community Handle
                      _buildLabel('HANDLE'),
                      TextFormField(
                        controller: _handleCtrl,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Handle is required';
                          if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(v)) {
                            return '3-30 chars, letters, numbers, or underscores only';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: _buildInputDecoration('e.g. flutter_devs', isDark).copyWith(
                          prefixIcon: const Icon(LucideIcons.at_sign, size: 16, color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildLabel('DESCRIPTION'),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: _buildInputDecoration('What is this community about?', isDark),
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      _buildLabel('CATEGORY'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _categories
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat.toUpperCase()),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _category = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Privacy Picker
                      _buildLabel('PRIVACY'),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(String value, String title, String subtitle, bool isDark) {
    final isSelected = _privacy == value;

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
              ? const Color(0xFFFD1D1D).withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFD1D1D).withOpacity(0.5)
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
                  color: isSelected ? const Color(0xFFFD1D1D) : Colors.white60,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFFFD1D1D) : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFFFD1D1D).withOpacity(0.7) : Colors.white38,
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
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
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
    );
  }
}
