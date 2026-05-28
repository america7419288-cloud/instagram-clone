import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:instagram_client/core/theme/app_theme.dart';
import '../models/browser_session.dart';

class BrowserHistorySheet extends StatelessWidget {
  final List<BrowserHistoryItem> history;
  final bool isDark;
  final Function(BrowserHistoryItem) onTap;

  const BrowserHistorySheet({
    super.key,
    required this.history,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                ? const Color(0xFF48484A)
                : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.clock_fill,
                  size: 20,
                  color: AppColors.iosBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Browser History',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 0.5),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return GestureDetector(
                        onTap: () => onTap(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFE5E5EA),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.globe,
                                size: 20,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title.isEmpty ? item.url : item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontSize: 12,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
