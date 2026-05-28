import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../controllers/story_controller.dart';
import '../widgets/story_header.dart';
import '../widgets/story_footer.dart';
import '../widgets/story_media_widget.dart';
import '../widgets/story_text_overlay.dart';
import '../widgets/story_poll_widget.dart';
import '../widgets/story_question_widget.dart';
import '../widgets/story_link_sticker.dart';
import 'story_reply_page.dart';

class StoryViewerPage extends StatefulWidget {
  final StoryController controller;
  final StoryUserModel user;
  final bool isActive;

  const StoryViewerPage({
    super.key,
    required this.controller,
    required this.user,
    required this.isActive,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  bool _showFloatingReactions = false;
  String? _activeReactionEmoji;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdated);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    super.dispose();
  }

  void _onControllerUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTap(TapUpDetails details) {
    if (widget.controller.isInputFocused) return;

    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < width * 0.3) {
      widget.controller.goToPrev();
    } else {
      widget.controller.goToNext();
    }
  }

  void _openReplySheet() {
    widget.controller.pause();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) => StoryReplyPage(
          story: widget.controller.currentStory,
          onReply: (replyText) {
            // Optimistic behavior or direct API call
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reply sent: "$replyText"'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onReaction: (emoji) {
            _triggerFloatingReaction(emoji);
          },
        ),
      ),
    ).then((_) {
      widget.controller.resume();
    });
  }

  void _triggerFloatingReaction(String emoji) {
    setState(() {
      _activeReactionEmoji = emoji;
      _showFloatingReactions = true;
    });
    // Hide reactions after animation completes
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showFloatingReactions = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(color: Colors.black);
    }

    final controller = widget.controller;
    final story = controller.currentStory;
    final isHolding = controller.isHolding;

    return GestureDetector(
      onTapUp: _handleTap,
      onLongPressStart: (_) => controller.pause(holding: true),
      onLongPressEnd: (_) => controller.resume(),
      onVerticalDragUpdate: (details) {
        controller.onDismissDragUpdate(details.primaryDelta ?? 0);
      },
      onVerticalDragEnd: (details) {
        controller.onDismissDragEnd(details.primaryVelocity ?? 0);
      },
      child: Transform.translate(
        offset: Offset(0, controller.dismissDragY),
        child: Transform.scale(
          scale: controller.dismissScale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(controller.dismissDragY > 0 ? 16 : 0),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Story Media Background
                  StoryMediaWidget(
                    story: story,
                    videoController: controller.videoController,
                    isVideoReady: controller.isVideoReady,
                  ),

                  // Bottom Shadow/Scrim
                  if (!isHolding)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 180,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Top Shadow/Scrim
                  if (!isHolding)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 2. Stickers / Interactive Layers
                  if (story.textOverlays.isNotEmpty)
                    ...story.textOverlays.map(
                      (overlay) => StoryTextOverlayWidget(overlay: overlay),
                    ),

                  if (story.poll != null)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45,
                      left: 0,
                      right: 0,
                      child: StoryPollWidget(
                        poll: story.poll!,
                        isOwner: widget.user.id == 'me', // optimistic check
                        onVote: (opt) => controller.votePoll(opt),
                      ),
                    ),

                  if (story.question != null)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.4,
                      left: 0,
                      right: 0,
                      child: StoryQuestionWidget(
                        question: story.question!,
                        onTap: _openReplySheet,
                      ),
                    ),

                  if (story.link != null)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.65,
                      left: 0,
                      right: 0,
                      child: StoryLinkSticker(
                        link: story.link!,
                        onTap: () {
                          // Standard hyper-link click
                        },
                      ),
                    ),

                  // 3. Header UI (Progress Bar & Profile details)
                  if (!isHolding)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: StoryHeader(
                        user: widget.user,
                        currentStoryIndex: controller.currentStoryIndex,
                        progressAnimation: controller.progressController,
                        onMoreTapped: () {},
                        onCloseTapped: () => Navigator.pop(context),
                        isOwner: widget.user.id == 'me',
                      ),
                    ),

                  // 4. Footer UI (Reply details & quick reactions)
                  if (!isHolding)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: StoryFooter(
                        story: story,
                        isOwner: widget.user.id == 'me',
                        onReply: (val) {
                          // Simple keyboard replies
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sent: $val')),
                          );
                        },
                        onReaction: _triggerFloatingReaction,
                        onShare: () {},
                        onFocusChanged: (focused) {
                          if (focused) {
                            _openReplySheet();
                          }
                        },
                      ),
                    ),

                  // 5. Floating Reaction particles overlay animation
                  if (_showFloatingReactions && _activeReactionEmoji != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _FloatingReactionsAnimator(
                          emoji: _activeReactionEmoji!,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating Reaction Animator ────────────────────────────────
class _FloatingReactionsAnimator extends StatefulWidget {
  final String emoji;

  const _FloatingReactionsAnimator({required this.emoji});

  @override
  State<_FloatingReactionsAnimator> createState() => _FloatingReactionsAnimatorState();
}

class _FloatingReactionsAnimatorState extends State<_FloatingReactionsAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ReactionParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Generate random particles floating upwards
    final random = javaRandom();
    for (int i = 0; i < 15; i++) {
      _particles.add(
        _ReactionParticle(
          startX: 100.0 + random.nextDouble() * 200.0,
          speedY: 2.0 + random.nextDouble() * 3.0,
          driftX: -1.0 + random.nextDouble() * 2.0,
          scale: 0.8 + random.nextDouble() * 0.8,
        ),
      );
    }
  }

  // Simple pseudo-random generator
  math.Random javaRandom() => math.Random();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          painter: _ParticlesPainter(
            emoji: widget.emoji,
            particles: _particles,
            progress: t,
          ),
        );
      },
    );
  }
}

class _ReactionParticle {
  final double startX;
  final double speedY;
  final double driftX;
  final double scale;

  _ReactionParticle({
    required this.startX,
    required this.speedY,
    required this.driftX,
    required this.scale,
  });
}

class _ParticlesPainter extends CustomPainter {
  final String emoji;
  final List<_ReactionParticle> particles;
  final double progress;

  _ParticlesPainter({
    required this.emoji,
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final p in particles) {
      final y = size.height - (progress * size.height * 0.7 * p.speedY / 5.0) - 100;
      final x = p.startX + (progress * 80.0 * p.driftX);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      textPainter.text = TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: 24 * p.scale,
          color: Colors.white.withOpacity(opacity),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
