// lib/features/reels/presentation/pages/reels_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/reel_provider.dart';
import '../widgets/reel_card.dart';

class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // ─── Hide status bar for immersive experience ──────
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // ─── Restore status bar ────────────────────────────
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // ─── Load more when near end ───────────────────────
    final reelState = ref.read(reelFeedProvider);
    if (index >= reelState.reels.length - 2) {
      ref.read(reelFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(reelFeedProvider.notifier).refresh();
    if (mounted) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final reelState = ref.watch(reelFeedProvider);

    // ─── Loading state ────────────────────────────────
    if (reelState.isLoading && reelState.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    // ─── Error state ──────────────────────────────────
    if (reelState.error != null && reelState.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ErrorView(
          message: reelState.error,
          onRetry: () => ref.read(reelFeedProvider.notifier).loadReels(),
        ),
      );
    }

    // ─── Empty state ──────────────────────────────────
    if (reelState.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_outline,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'No reels yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first to share a reel!',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _onRefresh,
                child: Text(
                  'Refresh',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─── Reels feed ───────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        physics: const _SnapPageScrollPhysics(),
        itemCount: reelState.hasMore
            ? reelState.reels.length + 1
            : reelState.reels.length,
        itemBuilder: (context, index) {
          // ─── Loading more indicator ──────────────────
          if (index == reelState.reels.length) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final reel = reelState.reels[index];

          return ReelCard(
            key: ValueKey(reel.id),
            reel: reel,
            isActive: index == _currentIndex,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// CUSTOM SNAP SCROLL PHYSICS
// Makes each reel snap fully into view
// ─────────────────────────────────────────────────────
class _SnapPageScrollPhysics extends ScrollPhysics {
  const _SnapPageScrollPhysics({super.parent});

  @override
  _SnapPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1,
      );
}