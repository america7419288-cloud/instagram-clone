// lib/core/router/app_router.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// iOS page transition
import 'ios_page_route.dart';

// Pages
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/create/presentation/pages/media_picker_page.dart';
import '../../features/post/presentation/pages/post_detail_page.dart';
import '../../features/post/presentation/pages/comments_page.dart';
import '../../features/search/presentation/pages/hashtag_page.dart';
import '../../features/post/presentation/pages/post_likes_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';

import '../../features/inbox/pages/inbox_page.dart';
import '../../features/inbox/pages/message_requests_page.dart';
import '../../features/messages/presentation/pages/chat_page.dart';
import '../../features/messages/presentation/pages/new_message_page.dart';
import '../../features/messages/presentation/pages/message_search_page.dart';
import '../../features/messages/presentation/pages/image_viewer_page.dart';
import '../../features/messages/presentation/pages/video_player_page.dart';
import '../../features/messages/presentation/pages/forward_message_page.dart';
import '../../features/messages/presentation/pages/group_chat_create_page.dart';
import '../../features/chat/data/models/message.dart';
import '../../features/story/presentation/pages/story_viewer_page.dart';
import '../../features/story/presentation/providers/story_provider.dart';

import '../../features/follow/data/repositories/presentation/pages/follow_requests_page.dart';
import '../../features/follow/data/repositories/presentation/pages/followers_page.dart';
import '../../features/reels/presentation/pages/reel_detail_page.dart';
import 'main_shell.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/server_settings_page.dart';
import '../../features/auth/presentation/pages/add_account_page.dart';
import '../../features/post/data/models/post_model.dart';
import '../../features/post/presentation/pages/finalize_post_page.dart';

// Auth provider
import '../../features/auth/presentation/providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String main = '/main';
  static const String home = '/main';
  static const String search = '/search';
  static const String reels = '/reels';
  static const String notifications = '/notifications';
  static const String messages = '/messages';
  static const String messageRequests = '/messages/requests';
  static const String chat = '/chat/:conversationId';
  static const String newMessage = '/new-message';
  static const String editProfile = '/profile/edit';
  static const String story = '/story/:userId';
  static const String createPost = '/create';
  static const String finalizePost = '/create/finalize';
  static const String createReel = '/create-reel';
  static const String createStory = '/create-story';
  static const String postDetail = '/post/:postId';
  static const String comments = '/post/:postId/comments';
  static const String profile = '/profile/:username';
  static const String settings = '/settings';
  static const String addAccount = '/add-account';
  static const String postLikes = '/post/:postId/likes';
  static const String reelDetail = '/reel/:reelId';
  static const String hashtag = '/hashtag/:tag';
  static const String followers = '/followers/:userId/:username';
  static const String following = '/following/:userId/:username';
  static const String followRequests = '/follow-requests';
  static const String serverSettings = '/settings/server';
}

CustomTransitionPage<void> _fadePage(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;

      if (isLoading) return AppRoutes.splash;

      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.serverSettings,
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      if (!isAuthenticated && !isPublicRoute) return AppRoutes.login;
      if (isAuthenticated && isPublicRoute && currentPath != AppRoutes.splash) return AppRoutes.main;

      return null;
    },

    routes: [
      // ── Auth pages — fade transition ──────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fadePage(context, state, const SplashPage()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadePage(context, state, const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _fadePage(context, state, const RegisterPage()),
      ),

      // ── Main App with Tabs (no push transition) ───────────
      GoRoute(
        path: '/home',
        redirect: (_, s) => AppRoutes.main,
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) => const MainShell(),
      ),

      // ── Full-screen routes — iOS slide transition ─────────
      GoRoute(
        path: AppRoutes.messages,
        pageBuilder: (context, state) => iosPage(state: state, child: const InboxPage()),
      ),
      GoRoute(
        path: AppRoutes.messageRequests,
        pageBuilder: (context, state) => iosPage(state: state, child: const MessageRequestsPage()),
      ),
      GoRoute(
        path: AppRoutes.chat,
        pageBuilder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';

          return iosPage(
            state: state,
            child: ChatPage(conversationId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.newMessage,
        pageBuilder: (context, state) => iosPage(state: state, child: const NewMessagePage()),
      ),
      GoRoute(
        path: '/messages/search',
        pageBuilder: (context, state) => iosPage(state: state, child: const MessageSearchPage()),
      ),
      GoRoute(
        path: '/messages/image-viewer',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return iosPage(
            state: state,
            child: ImageViewerPage(
              imageUrl: extra?['imageUrl'] as String? ?? '',
              senderName: extra?['senderName'] as String?,
              timestamp: extra?['timestamp'] as DateTime?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/messages/video-player',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return iosPage(
            state: state,
            child: VideoPlayerPage(
              videoUrl: extra?['videoUrl'] as String? ?? '',
              thumbnailUrl: extra?['thumbnailUrl'] as String?,
              senderName: extra?['senderName'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/messages/forward',
        pageBuilder: (context, state) {
          final message = state.extra as Message;
          return iosPage(state: state, child: ForwardMessagePage(message: message));
        },
      ),
      GoRoute(
        path: '/messages/group/create',
        pageBuilder: (context, state) => iosPage(state: state, child: const GroupChatCreatePage()),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => iosPage(state: state, child: const EditProfilePage()),
      ),
      GoRoute(
        path: AppRoutes.createPost,
        pageBuilder: (context, state) => iosPage(
          state: state,
          child: const MediaPickerPage(createType: CreateType.post),
        ),
      ),
      GoRoute(
        path: AppRoutes.finalizePost,
        pageBuilder: (context, state) {
          final extra = state.extra;
          List<File> images = [];
          List<List<double>> matrices = [];
          
          if (extra is File) {
            images = [extra];
          } else if (extra is List<File>) {
            images = extra;
          } else if (extra is Map<String, dynamic>) {
            images = extra['images'] as List<File>;
            matrices = extra['filterMatrices'] as List<List<double>>? ?? [];
          }
          
          return iosPage(
            state: state,
            child: FinalizePostPage(
              images: images,
              filterMatrices: matrices,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createReel,
        pageBuilder: (context, state) => iosPage(
          state: state,
          child: const MediaPickerPage(createType: CreateType.reel),
        ),
      ),
      GoRoute(
        path: AppRoutes.createStory,
        pageBuilder: (context, state) => iosPage(
          state: state,
          child: const MediaPickerPage(createType: CreateType.story),
        ),
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          return iosPage(state: state, child: PostDetailPage(postId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.comments,
        pageBuilder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          final post = state.extra as PostModel?;
          return iosPage(state: state, child: CommentsPage(postId: id, post: post));
        },
      ),

      // ── Story — custom zoom/expand transition (preserved) ─
      GoRoute(
        path: AppRoutes.story,
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          final originRect = extra?['originRect'] as Rect?;

          if (originRect == null) {
            return _fadePage(context, state, StoryViewerPage(userId: userId));
          }

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: StoryViewerPage(userId: userId),
            barrierColor: Colors.transparent,
            opaque: false,
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final isSwipeDismiss = ref.read(isSwipeDismissingProvider);
              if (isSwipeDismiss) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              }

              final screenSize = MediaQuery.of(context).size;

              final rectTween = RectTween(
                begin: originRect,
                end: Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
              );

              final rectAnimation = rectTween.animate(CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
                reverseCurve: Curves.easeIn,
              ));

              final borderRadiusTween = BorderRadiusTween(
                begin: BorderRadius.circular(originRect.width / 2),
                end: BorderRadius.zero,
              );

              final borderRadiusAnimation = borderRadiusTween.animate(CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
                reverseCurve: Curves.easeIn,
              ));

              final backgroundOpacity = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.5),
                reverseCurve: const Interval(0.5, 1.0),
              ));

              final contentOpacity = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.6, 1.0),
                reverseCurve: const Interval(0.0, 0.4),
              ));

              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final rect = rectAnimation.value ?? originRect;
                  final radius = borderRadiusAnimation.value ?? BorderRadius.zero;
                  final bgOp = backgroundOpacity.value;
                  final contentOp = contentOpacity.value;

                  return Stack(
                    children: [
                      Opacity(
                        opacity: bgOp,
                        child: Container(color: Colors.black),
                      ),
                      Positioned(
                        left: rect.left,
                        top: rect.top,
                        width: rect.width,
                        height: rect.height,
                        child: ClipRRect(
                          borderRadius: radius,
                          child: Opacity(
                            opacity: contentOp,
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),

      // ── Remaining pages — iOS slide transition ────────────
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => iosPage(state: state, child: const SettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.serverSettings,
        pageBuilder: (context, state) => iosPage(state: state, child: const ServerSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.addAccount,
        pageBuilder: (context, state) => iosPage(state: state, child: const AddAccountPage()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return iosPage(state: state, child: ProfilePage(username: username));
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => iosPage(state: state, child: const NotificationsPage()),
      ),
      GoRoute(
        path: AppRoutes.postLikes,
        pageBuilder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          return iosPage(state: state, child: PostLikesPage(postId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.reelDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters['reelId'] ?? '';
          return iosPage(state: state, child: ReelDetailPage(reelId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.hashtag,
        pageBuilder: (context, state) {
          final tag = state.pathParameters['tag'] ?? '';
          return iosPage(state: state, child: HashtagPage(tag: tag));
        },
      ),
      GoRoute(
        path: AppRoutes.followers,
        pageBuilder: (context, state) {
          final id = state.pathParameters['userId'] ?? '';
          final username = state.pathParameters['username'] ?? '';
          return iosPage(state: state, child: FollowersPage(userId: id, username: username));
        },
      ),
      GoRoute(
        path: AppRoutes.following,
        pageBuilder: (context, state) {
          final id = state.pathParameters['userId'] ?? '';
          final username = state.pathParameters['username'] ?? '';
          return iosPage(state: state, child: FollowingPage(userId: id, username: username));
        },
      ),
      GoRoute(
        path: AppRoutes.followRequests,
        pageBuilder: (context, state) => iosPage(state: state, child: const FollowRequestsPage()),
      ),
    ],
  );
});
