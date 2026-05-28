import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/browser_session.dart';

class BrowserAdBanner extends StatelessWidget {
  final BrowserSession session;

  const BrowserAdBanner({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A233A) : const Color(0xFFE8F0FE),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF293754) : const Color(0xFFD2E3FC),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF1A73E8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.adSource != null
                      ? 'Sponsored by ${session.adSource}'
                      : 'Sponsored content',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1967D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (session.adCampaignId != null)
                  Text(
                    'Campaign: ${session.adCampaignId}',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF5F6368),
                      fontSize: 10,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Ad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
