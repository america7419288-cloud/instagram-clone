import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

class EventWidget extends StatelessWidget {
  final Map<String, dynamic> event;
  final String currentUserId;
  final VoidCallback onRSVP;

  const EventWidget({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.onRSVP,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = event['title'] as String? ?? 'Event';
    final description = event['description'] as String? ?? '';
    final startDateStr = event['startDate'] as String?;
    final endDateStr = event['endDate'] as String?;
    final location = event['location'] as String? ?? 'Online';
    final coverUrl = event['coverUrl'] as String?;
    final attendees = List<String>.from(event['attendees'] ?? []);

    final startDate = startDateStr != null ? DateTime.parse(startDateStr) : DateTime.now();
    final isAttending = attendees.contains(currentUserId);

    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('dd');
    final timeFormat = DateFormat('h:mm a');

    final month = monthFormat.format(startDate).toUpperCase();
    final day = dayFormat.format(startDate);
    final time = timeFormat.format(startDate);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Banner/Cover
            if (coverUrl != null && coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultBanner(isDark),
              )
            else
              _buildDefaultBanner(isDark),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Date Badge
                  Container(
                    width: 52,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          month,
                          style: const TextStyle(
                            color: Color(0xFFFD1D1D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          day,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title and Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Time Info
                        Row(
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Location Info
                        Row(
                          children: [
                            Icon(
                              LucideIcons.map_pin,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Attendees count + Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Attendees avatars/text
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.users,
                                  size: 15,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${attendees.length} attending',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            // RSVP Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                onRSVP();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isAttending
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                                        ),
                                  color: isAttending
                                      ? (isDark ? Colors.white12 : Colors.black.withOpacity(0.05))
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  isAttending ? 'Attending' : 'RSVP',
                                  style: TextStyle(
                                    color: isAttending
                                        ? (isDark ? Colors.white70 : Colors.black87)
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner(bool isDark) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1F1C2C), const Color(0xFF928DAB)]
              : [const Color(0xFFE2E2E2), const Color(0xFFC9D6FF)],
        ),
      ),
      child: const Center(
        child: Icon(
          LucideIcons.calendar_days,
          color: Colors.white60,
          size: 40,
        ),
      ),
    );
  }
}
