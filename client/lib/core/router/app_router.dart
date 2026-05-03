// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Pages
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/story/presentation/pages/story_create_page.dart';
import '../../features/post/presentation/pages/create_post_page.dart';
import '../../features/post/presentation/pages/post_detail_page.dart';
import '../../features/search/presentation/pages/hashtag_page.dart';
import '../../features/post/presentation/pages/post_likes_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/reels/presentation/pages/reels_page.dart';
import '../../features/messages/presentation/pages/chat_page.dart';
import '../../features/reels/presentation/pages/create_reel_page.dart';
import '../../features/messages/presentation/pages/new_message_page.dart';
import '../../features/story/presentation/pages/story_viewer_page.dart';
import '../../features/story/presentation/pages/story_creator_page.dart';
import '../../features/follow/data/repositories/presentation/pages/followers_page.dart';
import '../../features/follow/data/repositories/presentation/pages/follow_requests_page.dart';
import 'main_shell.dart';
import '../../features/settings/presentation/pages/settings_page.dart';


// Auth provider
import '../../features/auth/presentation/providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// ─── ROUTE NAMES ────────────────────────────────────────────
// Use these constants instead of hardcoded strings
// Prevents typos and makes refactoring easy
class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String search = '/search';
  static const String reels = '/reels';
  static const String createPost = '/create';
  static const String createReel = '/create-reel';
  static const String notifications = '/notifications';
  static const String messages = '/messages';
  static const String newMessage = '/new-message';
  static const String chat = '/chat/:conversationId';
  static const String profile = '/profile/:username';
  static const String editProfile = '/profile/edit';
  static const String postDetail = '/post/:postId';
  static const String story = '/story/:userId';
  static const String followers = '/followers/:userId';
  static const String following = '/following/:userId';
  static const String followRequests = '/follow-requests';
  static const String postLikes = '/post/:postId/likes';
  static const String hashtag = '/hashtag/:tag';
  static const String settings = '/settings';
  static const String storyCreate = '/story-create';
  static const String createStory = '/create-story';
  static const String myProfile = '/my-profile';
}

// ─── ROUTER PROVIDER ────────────────────────────────────────
// Riverpod provider for GoRouter
// Listens to auth state changes and redirects
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Starting route
    initialLocation: AppRoutes.splash,

    // Enable URL-based navigation (important for web + deep links)
    debugLogDiagnostics: true, // Shows route changes in console
    // ─── REDIRECT (Auth Guard) ──────────────────────────
    // Runs before EVERY navigation
    // Decides: show this route or redirect somewhere else?
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;

      // While checking auth (app startup) → show splash
      if (isLoading) {
        return AppRoutes.splash;
      }

      // Public routes - no auth needed
      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
      ];

      final isPublicRoute = publicRoutes.contains(currentPath);

      // NOT logged in + trying to access protected route
      // → redirect to login
      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      // Already logged in + trying to access login/register
      // → redirect to home
      if (isAuthenticated && isPublicRoute && currentPath != AppRoutes.splash) {
        return AppRoutes.home;
      }

      // No redirect needed → show the requested route
      return null;
    },

    // ─── ROUTES ─────────────────────────────────────────
    routes: [
      // ── SPLASH ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      GoRoute(
        path: AppRoutes.hashtag,
        name: 'hashtag',
        builder: (context, state) {
          final tag = state.pathParameters['tag'] ?? '';
          return HashtagPage(tag: tag);
        },
      ),

      // ── AUTH ROUTES ─────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),

      GoRoute(
  path: '/story-create',
  name: 'storyCreate',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: const StoryCreatePage(),
    transitionsBuilder: (context, animation, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), // Slides up from bottom
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        )),
        child: child,
      );
    },
  ),
),

      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        // Slide from right animation
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterPage(),
          transitionsBuilder: (context, animation, secondary, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0), // From right
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            );
          },
        ),
      ),

      // ── MAIN APP ROUTES ─────────────────────────────
      // These use ShellRoute to keep bottom nav visible
      // Edit Profile
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.editProfile,
        name: 'editProfile',
        builder: (context, state) => const EditProfilePage(),
      ),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Home Feed
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomePageContent(),
          ),

          // Search & Explore
          GoRoute(
            path: AppRoutes.search,
            name: 'search',
            builder: (context, state) => const SearchPage(),
          ),

          // Reels
          GoRoute(
            path: AppRoutes.reels,
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const ReelsPage(),
            ),
          ),

          // Notifications
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsPage(),
          ),

          // Profile (own or other user)
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) {
              // Get :username from route params
              final username = state.pathParameters['username'] ?? '';
              return ProfilePage(username: username);
            },
          ),

          // Messages List
          GoRoute(
            path: AppRoutes.messages,
            name: 'messages',
            builder: (context, state) => const MessagesPage(),
          ),

          // My Profile (redirect helper)
          GoRoute(
            path: AppRoutes.myProfile,
            name: 'myProfile',
            builder: (context, state) {
              final user = ref.read(authProvider).user;
              return ProfilePage(username: user?.username ?? '');
            },
          ),
        ],
      ),

      // ── FULL SCREEN ROUTES ──────────────────────────
      // These don't show bottom nav

      // Create Reel (full screen)
      GoRoute(
        path: AppRoutes.createReel,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const CreateReelPage(),
        ),
      ),

      // Create Post (full screen)
      GoRoute(
        path: AppRoutes.createPost,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const CreatePostPage(),
        ),
      ),

      // Create Story (full screen)
      GoRoute(
        path: AppRoutes.createStory,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const StoryCreatorPage(),
        ),
      ),

      // Post Detail
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.postDetail,
        name: 'postDetail',
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return PostDetailPage(postId: postId);
        },
      ),

      // Post Likes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.postLikes,
        name: 'postLikes',
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return PostLikesPage(postId: postId);
        },
      ),

      // Chat / Conversation
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.newMessage,
        name: 'newMessage',
        builder: (context, state) => const NewMessagePage(),
      ),

      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return ChatPage(
            conversationId: conversationId,
          );
        },
      ),

      // Story Viewer
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.story,
        name: 'story',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: StoryViewerPage(userId: state.pathParameters['userId'] ?? ''),
          transitionsBuilder: (context, animation, secondary, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Followers List
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.followers,
        name: 'followers',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final username = state.uri.queryParameters['username'] ?? '';
          return FollowersPage(userId: userId, username: username);
        },
      ),

      // Following List
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.following,
        name: 'following',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final username = state.uri.queryParameters['username'] ?? '';
          return FollowingPage(userId: userId, username: username);
        },
      ),

      // Follow Requests
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.followRequests,
        name: 'followRequests',
        builder: (context, state) => const FollowRequestsPage(),
      ),
    ],

    // ─── ERROR PAGE ─────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Route not found:\n${state.uri}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ─── HELPERS ────────────────────────────────────────────────
Page<dynamic> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
