// lib/features/auth/signup/presentation/follow_suggestions_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/suggested_user.dart';
import '../controllers/follow_suggestions_controller.dart';
import 'widgets/suggestion_tile.dart';
import 'theme/auth_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../follow/data/repositories/presentation/providers/follow_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN SCREEN
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class FollowSuggestionsScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const FollowSuggestionsScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<FollowSuggestionsScreen> createState() =>
      _FollowSuggestionsScreenState();
}

class _FollowSuggestionsScreenState
    extends ConsumerState<FollowSuggestionsScreen> {

  late final FollowSuggestionsController _controller;
  final ScrollController _scrollController =
      ScrollController();
  bool _showStickyHeader = false;

  @override
  void initState() {
    super.initState();
    _controller = FollowSuggestionsController(ref.read(followServiceProvider));
    _controller.addListener(_rebuild);
    _controller.loadSuggestions();

    // Status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final show = _scrollController.offset > 60;
      if (show != _showStickyHeader) {
        setState(() => _showStickyHeader = show);
      }
    });
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AuthColors.white,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: fontFamily,
          color: AuthColors.primaryText,
          decoration: TextDecoration.none,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // ── Main scrollable content
                _buildBody(),

                // ── Sticky header (shows on scroll)
                if (_showStickyHeader) _buildStickyHeader(),

                // ── Bottom Action Bar
                if (!_controller.isLoading &&
                    !_controller.hasError &&
                    _controller.allSuggestions.isNotEmpty)
                  BottomActionBar(
                    followedCount: _controller.followedCount,
                    onContinue: widget.onComplete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────

  Widget _buildBody() {
    if (_controller.isLoading) {
      return _LoadingState();
    }

    if (_controller.hasError) {
      return _ErrorState(
        message: _controller.errorMessage!,
        onRetry: _controller.retry,
      );
    }

    if (_controller.allSuggestions.isEmpty) {
      return _EmptyState(onSkip: widget.onComplete);
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [

        // Top header (logo + skip)
        SliverToBoxAdapter(
          child: _TopBar(
            onSkip: _confirmSkip,
            isLoading: _controller.isFollowingAll,
          ),
        ),

        // Title & subtitle
        SliverToBoxAdapter(
          child: _HeaderText(),
        ),

        // Follow All button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 8, 16, 0),
            child: _FollowAllButton(
              onTap: _controller.followAll,
              isLoading: _controller.isFollowingAll,
              followedCount: _controller.followedCount,
              totalCount: _controller.totalCount,
            ),
          ),
        ),

        // Categories with users
        ..._buildCategorySections(),

        // Bottom padding for the fixed button
        SliverToBoxAdapter(
          child: SizedBox(
            height: 120 +
                MediaQuery.of(context).padding.bottom,
          ),
        ),
      ],
    );
  }

  // ── Category Sections ──────────────────────

  List<Widget> _buildCategorySections() {
    final widgets = <Widget>[];
    
    // Order matters: contacts → suggested → popular
    final orderedCategories = [
      SuggestionCategory.contacts,
      SuggestionCategory.suggested,
      SuggestionCategory.popular,
      SuggestionCategory.newAccounts,
    ];

    for (final category in orderedCategories) {
      final users = _controller.getByCategory(category);
      if (users.isEmpty) continue;

      // Section header
      widgets.add(
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: _getCategoryTitle(category),
            count: users.length,
          ),
        ),
      );

      // User tiles
      widgets.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => SuggestionTile(
              user: users[i],
              onFollowTap: () =>
                  _controller.toggleFollow(users[i].id),
            ),
            childCount: users.length,
          ),
        ),
      );
    }

    return widgets;
  }

  String _getCategoryTitle(SuggestionCategory category) {
    switch (category) {
      case SuggestionCategory.contacts:
        return 'From your contacts';
      case SuggestionCategory.suggested:
        return 'Suggested for you';
      case SuggestionCategory.popular:
        return 'Popular on Instagram';
      case SuggestionCategory.newAccounts:
        return 'New accounts';
    }
  }

  // ── Sticky Header ──────────────────────────

  Widget _buildStickyHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: AuthColors.white,
          border: Border(
            bottom: BorderSide(
              color: AuthColors.separator,
              width: 0.33,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Discover people',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: fontFamily,
                  color: AuthColors.primaryText,
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _confirmSkip,
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: fontFamily,
                  color: AuthColors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Skip Confirmation ──────────────────────

  void _confirmSkip() {
    if (!_controller.hasFollowedAny) {
      // Show confirmation dialog
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text(
            'Skip following accounts?',
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Following accounts helps personalize '
              'your feed. You can always follow people '
              'later from your profile.',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 14,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Stay',
                style: TextStyle(
                  fontFamily: fontFamily,
                ),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                widget.onComplete();
              },
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontFamily: fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TOP BAR (back chevron + skip)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopBar extends StatelessWidget {
  final VoidCallback onSkip;
  final bool isLoading;

  const _TopBar({
    required this.onSkip,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          12, 8, 16, 0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          // Back chevron
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Icon(
              LucideIcons.chevronLeft,
              size: 28,
              color: AuthColors.primaryText,
            ),
          ),
          
          // Skip button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            onPressed: isLoading ? null : onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamily,
                color: isLoading
                    ? AuthColors.blueDisabled
                    : AuthColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HEADER TEXT (title + subtitle)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HeaderText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Discover people to follow',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: fontFamily,
              color: AuthColors.primaryText,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Following accounts personalizes your '
            'experience and helps your feed reflect '
            'what you love.',
            style: TextStyle(
              fontSize: 15,
              fontFamily: fontFamily,
              color: AuthColors.primaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FOLLOW ALL BUTTON
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FollowAllButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final int followedCount;
  final int totalCount;

  const _FollowAllButton({
    required this.onTap,
    required this.isLoading,
    required this.followedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final allFollowed = followedCount == totalCount && totalCount > 0;
    
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: (isLoading || allFollowed)
            ? null
            : onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: allFollowed
                ? AuthColors.buttonGray
                : (isLoading
                    ? AuthColors.blueDisabled
                    : AuthColors.blue),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const CupertinoActivityIndicator(
                  color: Colors.white,
                )
              : Text(
                  allFollowed
                      ? 'Following all'
                      : 'Follow all',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily,
                    color: allFollowed
                        ? AuthColors.primaryText
                        : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SECTION HEADER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          16, 24, 16, 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: fontFamily,
              color: AuthColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LOADING STATE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CupertinoActivityIndicator(radius: 14),
          SizedBox(height: 16),
          Text(
            'Finding people for you...',
            style: TextStyle(
              fontSize: 14,
              color: AuthColors.secondaryText,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ERROR STATE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.wifiOff,
              size: 48,
              color: AuthColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AuthColors.primaryText,
                fontFamily: fontFamily,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.blue,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// EMPTY STATE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EmptyState extends StatelessWidget {
  final VoidCallback onSkip;

  const _EmptyState({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.users,
              size: 48,
              color: AuthColors.secondaryText,
            ),
            const SizedBox(height: 16),
            const Text(
              'No suggestions right now',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamily,
                color: AuthColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can find people to follow '
              'from your profile later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AuthColors.secondaryText,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.blue,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BOTTOM ACTION BAR (Sticky Continue)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BottomActionBar extends StatelessWidget {
  final int followedCount;
  final VoidCallback onContinue;

  const BottomActionBar({
    super.key,
    required this.followedCount,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AuthColors.white,
          border: const Border(
            top: BorderSide(
              color: AuthColors.separator,
              width: 0.33,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Followed count text
            if (followedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  followedCount == 1
                      ? 'Following 1 account'
                      : 'Following $followedCount accounts',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AuthColors.secondaryText,
                    fontFamily: fontFamily,
                  ),
                ),
              ),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onContinue();
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AuthColors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
