import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class PollWidget extends StatelessWidget {
  final Map<String, dynamic> poll;
  final String currentUserId;
  final ValueChanged<int> onVote;

  const PollWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final question = poll['question'] as String? ?? 'Poll';
    final options = (poll['options'] as List?)?.map((x) => Map<String, dynamic>.from(x)).toList() ?? [];
    final endsAtStr = poll['endsAt'] as String?;
    final endsAt = endsAtStr != null ? DateTime.parse(endsAtStr) : null;
    final isExpired = endsAt != null && DateTime.now().isAfter(endsAt);

    // Calculate total votes
    int totalVotes = 0;
    bool hasVoted = false;
    int userVotedIndex = -1;

    for (int i = 0; i < options.length; i++) {
      final votes = List<String>.from(options[i]['votes'] ?? []);
      totalVotes += votes.length;
      if (votes.contains(currentUserId)) {
        hasVoted = true;
        userVotedIndex = i;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'POLL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isExpired
                    ? 'Closed'
                    : endsAt != null
                        ? '${endsAt.difference(DateTime.now()).inDays}d left'
                        : 'Active',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Question
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          // Options
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final option = options[index];
              final optionText = option['text'] as String? ?? '';
              final votes = List<String>.from(option['votes'] ?? []);
              final voteCount = votes.length;
              final isUserVote = userVotedIndex == index;

              final percent = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
              final percentDisplay = '${(percent * 100).toStringAsFixed(0)}%';

              return GestureDetector(
                onTap: (isExpired)
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onVote(index);
                      },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Background Bar
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUserVote
                                ? const Color(0xFFFD1D1D).withOpacity(0.5)
                                : isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                            width: isUserVote ? 1.5 : 1.0,
                          ),
                        ),
                      ),
                      // Animated Fill Bar
                      if (hasVoted || isExpired)
                        FractionallySizedBox(
                          widthFactor: percent.clamp(0.01, 1.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isUserVote
                                    ? [const Color(0xFF833AB4).withOpacity(0.35), const Color(0xFFFD1D1D).withOpacity(0.35)]
                                    : [
                                        isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                                        isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      // Content inside option
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (isUserVote)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFFFD1D1D),
                                          size: 18,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isUserVote ? FontWeight.w700 : FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasVoted || isExpired)
                                Text(
                                  '$voteCount ($percentDisplay)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isUserVote ? FontWeight.w700 : FontWeight.w500,
                                    color: isUserVote
                                        ? const Color(0xFFFD1D1D)
                                        : isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (totalVotes > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$totalVotes votes • ${hasVoted ? "Thanks for voting!" : "Vote to see results"}',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
