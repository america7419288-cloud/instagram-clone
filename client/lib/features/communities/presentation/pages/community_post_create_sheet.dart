import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:ui';

class CommunityPostCreateSheet extends StatefulWidget {
  final Function(
    String? content,
    String type,
    Map<String, dynamic>? poll,
    Map<String, dynamic>? event,
    List<String>? mediaPaths,
  ) onSubmit;

  const CommunityPostCreateSheet({super.key, required this.onSubmit});

  @override
  State<CommunityPostCreateSheet> createState() => _CommunityPostCreateSheetState();
}

class _CommunityPostCreateSheetState extends State<CommunityPostCreateSheet> {
  int _tab = 0; // 0: Post, 1: Poll, 2: Event
  final TextEditingController _contentCtrl = TextEditingController();

  // Poll fields
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionCtrls = [
    TextEditingController(text: 'Yes'),
    TextEditingController(text: 'No'),
  ];

  // Event fields
  final TextEditingController _eventTitleCtrl = TextEditingController();
  final TextEditingController _eventDescCtrl = TextEditingController();
  final TextEditingController _eventLocCtrl = TextEditingController();
  DateTime _eventStartDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _contentCtrl.dispose();
    _pollQuestionCtrl.dispose();
    for (final ctrl in _pollOptionCtrls) {
      ctrl.dispose();
    }
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    _eventLocCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _contentCtrl.text.trim();
    String type = 'text';
    Map<String, dynamic>? poll;
    Map<String, dynamic>? event;

    if (_tab == 1) {
      type = 'poll';
      final question = _pollQuestionCtrl.text.trim();
      final options = _pollOptionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (question.isEmpty || options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll must have a question and at least 2 options.')),
        );
        return;
      }
      poll = {
        'question': question,
        'options': options,
        'durationDays': 7,
      };
    } else if (_tab == 2) {
      type = 'event';
      final title = _eventTitleCtrl.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event must have a title.')),
        );
        return;
      }
      event = {
        'title': title,
        'description': _eventDescCtrl.text.trim(),
        'startDate': _eventStartDate.toIso8601String(),
        'location': _eventLocCtrl.text.trim().isNotEmpty ? _eventLocCtrl.text.trim() : 'Online',
      };
    } else {
      type = 'text';
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post content cannot be empty.')),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();
    widget.onSubmit(
      content.isNotEmpty ? content : null,
      type,
      poll,
      event,
      null, // mediaPaths placeholder
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.76) : Colors.white.withOpacity(0.9),
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

            // Tab Bar Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Community Post',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      'Share',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs Picker
            Row(
              children: [
                _buildTabPill('Standard', 0, LucideIcons.file_text),
                const SizedBox(width: 8),
                _buildTabPill('Poll', 1, LucideIcons.chart_bar),
                const SizedBox(width: 8),
                _buildTabPill('Event', 2, LucideIcons.calendar),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // Input Feed Section
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _tab == 0
                    ? _buildStandardTab(isDark)
                    : _tab == 1
                        ? _buildPollTab(isDark)
                        : _buildEventTab(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String label, int idx, IconData icon) {
    final isActive = _tab == idx;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _tab = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TABS LAYOUTS ──────────────────────────────────────────
  Widget _buildStandardTab(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _contentCtrl,
          maxLines: 8,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "What's happening in this community channel?",
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _buildPollTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pollQuestionCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Ask a question...",
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'OPTIONS',
          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pollOptionCtrls.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollOptionCtrls[index],
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Add option...',
                      ),
                    ),
                  ),
                  if (_pollOptionCtrls.length > 2)
                    IconButton(
                      icon: const Icon(LucideIcons.circle_minus, size: 16, color: Colors.white38),
                      onPressed: () {
                        setState(() {
                          _pollOptionCtrls.removeAt(index);
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
        if (_pollOptionCtrls.length < 8) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _pollOptionCtrls.add(TextEditingController());
              });
            },
            child: const Row(
              children: [
                Icon(LucideIcons.circle_plus, size: 16, color: Color(0xFFFD1D1D)),
                SizedBox(width: 8),
                Text('Add Option', style: TextStyle(color: Color(0xFFFD1D1D), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _eventTitleCtrl,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Event Title',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _eventDescCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Event Description (optional)',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
            border: InputBorder.none,
          ),
        ),
        const Divider(color: Colors.white12, height: 20),
        const SizedBox(height: 8),
        // Date Selector
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.calendar_days, color: Colors.white70),
          title: const Text('Event Date', style: TextStyle(fontSize: 13, color: Colors.white54)),
          subtitle: Text(
            '${_eventStartDate.year}-${_eventStartDate.month.toString().padLeft(2, '0')}-${_eventStartDate.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(LucideIcons.chevron_right, size: 16),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _eventStartDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _eventStartDate = picked);
            }
          },
        ),
        const Divider(color: Colors.white12, height: 20),
        const SizedBox(height: 8),
        TextField(
          controller: _eventLocCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Location (default: Online)',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
            prefixIcon: const Icon(LucideIcons.map_pin, size: 16, color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }
}
