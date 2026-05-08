// lib/features/home/presentation/widgets/suggested_users_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';
import '../providers/suggestion_provider.dart';

class SuggestedUsersCard extends ConsumerWidget {
  final VoidCallback? onSeeAll;

  const SuggestedUsersCard({
    super.key,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionState = ref.watch(suggestionProvider);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    if (suggestionState.isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (suggestionState.users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested for you',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onSeeAll,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Horizontal List ─────────────────────────────────
        SizedBox(
          height: 280,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: suggestionState.users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final user = suggestionState.users[index];
              return _UserSuggestionCard(
                user: user,
                onRemove: () => ref.read(suggestionProvider.notifier).removeSuggestion(user.id),
                isDark: isDark,
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        Divider(
          height: 0.33,
          thickness: 0.33,
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFDBDBDB),
        ),
      ],
    );
  }
}

class _UserSuggestionCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRemove;
  final bool isDark;

  const _UserSuggestionCard({
    required this.user,
    required this.onRemove,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFDBDBDB),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          // Close Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(
                LucideIcons.x,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar with Story Ring
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(2.5), // Gap for ring
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF833AB4), // Purple
                        Color(0xFFF77737), // Orange
                        Color(0xFFE1306C), // Pink/Red
                        Color(0xFFC13584), // Magenta
                        Color(0xFF833AB4), // Purple back
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3), // White gap
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: user.profilePicUrl != null
                            ? DecorationImage(
                                image: NetworkImage(user.profilePicUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEFEFEF),
                      ),
                      child: user.profilePicUrl == null
                          ? Icon(LucideIcons.user, 
                              size: 45, 
                              color: isDark ? Colors.white24 : Colors.black26)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                
                // Username
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                // Full Name / Mutual info
                Text(
                  'Suggested for you',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Follow Button
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: _DiscoverFollowButton(userId: user.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverFollowButton extends ConsumerWidget {
  final String userId;

  const _DiscoverFollowButton({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followProvider(userId));
    final notifier = ref.read(followProvider(userId).notifier);
    
    final isFollowing = followState.isFollowing;
    final isRequested = followState.isPending;
    final isLoading = followState.isLoading;

    Color buttonColor;
    String text;
    Color textColor;
    BoxBorder? border;

    if (isFollowing) {
      buttonColor = CupertinoTheme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF262626) 
          : const Color(0xFFEFEFEF);
      text = 'Following';
      textColor = CupertinoTheme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black;
      border = null;
    } else if (isRequested) {
      buttonColor = CupertinoTheme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF262626) 
          : const Color(0xFFEFEFEF);
      text = 'Requested';
      textColor = CupertinoTheme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black;
      border = null;
    } else {
      buttonColor = const Color(0xFF0095F6);
      text = 'Follow';
      textColor = Colors.white;
      border = null;
    }

    return BouncyTap(
      onTap: isLoading ? null : () => notifier.toggleFollow(),
      child: Container(
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CupertinoActivityIndicator(radius: 7),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
