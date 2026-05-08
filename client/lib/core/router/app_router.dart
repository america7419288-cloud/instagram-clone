// lib/core/router/app_router.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/messages/presentation/pages/new_message_page.dart';
import '../../features/messages/data/models/conversation_model.dart';
import '../../features/reels/presentation/pages/reel_detail_page.dart';
import '../../features/story/presentation/pages/story_viewer_page.dart';
import '../../features/follow/data/repositories/presentation/pages/followers_page.dart';
import '../../features/follow/data/repositories/presentation/pages/follow_requests_page.dart';
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
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      if (!isAuthenticated && !isPublicRoute) return AppRoutes.login;
      if (isAuthenticated && isPublicRoute && currentPath != AppRoutes.splash) return AppRoutes.main;

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),

      // ⭐ Main App with Tabs
      GoRoute(
        path: '/home',
        redirect: (_, s) => AppRoutes.main,
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) => const MainShell(),
      ),

      // Full screen routes (hide tabs)
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagesPage(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          final extra = state.extra;
          
          String username = 'User';
          String? avatarUrl;
          bool isVerified = false;
          
          if (extra is ConversationModel) {
            username = extra.displayName;
            avatarUrl = extra.displayAvatarUrl;
            isVerified = extra.otherUser?.isVerified ?? false;
          } else if (extra is Map<String, dynamic>) {
            username = extra['username'] ?? 'User';
            avatarUrl = extra['avatarUrl'];
            isVerified = extra['isVerified'] ?? false;
          }

          return ChatScreen(
            conversationId: id,
            username: username,
            avatarUrl: avatarUrl,
            isVerified: isVerified,
            isOnline: true, // Fallback
          );
        },
      ),
      GoRoute(
        path: AppRoutes.newMessage,
        builder: (context, state) => const NewMessagePage(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.createPost,
        builder: (context, state) =>
            const MediaPickerPage(createType: CreateType.post),
      ),
      GoRoute(
        path: AppRoutes.finalizePost,
        builder: (context, state) {
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
          
          return FinalizePostPage(
            images: images,
            filterMatrices: matrices,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createReel,
        builder: (context, state) =>
            const MediaPickerPage(createType: CreateType.reel),
      ),
      GoRoute(
        path: AppRoutes.createStory,
        builder: (context, state) =>
            const MediaPickerPage(createType: CreateType.story),
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        builder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          return PostDetailPage(postId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.comments,
        builder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          final post = state.extra as PostModel?;
          return CommentsPage(postId: id, post: post);
        },
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (context, state) => StoryViewerPage(userId: state.pathParameters['userId'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.serverSettings,
        builder: (context, state) => const ServerSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.addAccount,
        builder: (context, state) => const AddAccountPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ProfilePage(username: username);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.postLikes,
        builder: (context, state) {
          final id = state.pathParameters['postId'] ?? '';
          return PostLikesPage(postId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.reelDetail,
        builder: (context, state) {
          final id = state.pathParameters['reelId'] ?? '';
          return ReelDetailPage(reelId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.hashtag,
        builder: (context, state) {
          final tag = state.pathParameters['tag'] ?? '';
          return HashtagPage(tag: tag);
        },
      ),
      GoRoute(
        path: AppRoutes.followers,
        builder: (context, state) {
          final id = state.pathParameters['userId'] ?? '';
          final username = state.pathParameters['username'] ?? '';
          return FollowersPage(userId: id, username: username);
        },
      ),
      GoRoute(
        path: AppRoutes.following,
        builder: (context, state) {
          final id = state.pathParameters['userId'] ?? '';
          final username = state.pathParameters['username'] ?? '';
          return FollowingPage(userId: id, username: username);
        },
      ),
      GoRoute(
        path: AppRoutes.followRequests,
        builder: (context, state) => const FollowRequestsPage(),
      ),
    ],
  );
});
