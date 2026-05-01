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
import '../../features/post/presentation/pages/create_post_page.dart';
import '../../features/post/presentation/pages/post_detail_page.dart';
import '../../features/post/presentation/pages/post_likes_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';
import '../../features/messages/presentation/pages/chat_page.dart';
import '../../features/story/presentation/pages/story_viewer_page.dart';
import 'main_shell.dart';

// Auth provider
import '../../features/auth/presentation/providers/auth_provider.dart';

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
  static const String createPost = '/create';
  static const String notifications = '/notifications';
  static const String messages = '/messages';
  static const String chat = '/messages/:conversationId';
  static const String profile = '/profile/:username';
  static const String editProfile = '/profile/edit';
  static const String postDetail = '/post/:postId';
  static const String story = '/story/:userId';
  static const String followers = '/followers/:username';
  static const String following = '/following/:username';
  static const String postLikes = '/post/:postId/likes';
}

// ─── ROUTER PROVIDER ────────────────────────────────────────
// Riverpod provider for GoRouter
// Listens to auth state changes and redirects
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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

      // ── AUTH ROUTES ─────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
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
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
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
        ],
      ),

      // ── FULL SCREEN ROUTES ──────────────────────────
      // These don't show bottom nav

      // Create Post (full screen)
      GoRoute(
        path: AppRoutes.createPost,
        name: 'createPost',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CreatePostPage(),
          transitionsBuilder: (context, animation, secondary, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1), // From bottom
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            );
          },
        ),
      ),

      // Post Detail
      GoRoute(
        path: AppRoutes.postDetail,
        name: 'postDetail',
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return PostDetailPage(postId: postId);
        },
      ),

      // Post Likes
      GoRoute(
        path: AppRoutes.postLikes,
        name: 'postLikes',
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return PostLikesPage(postId: postId);
        },
      ),

      // Edit Profile
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'editProfile',
        builder: (context, state) => const EditProfilePage(),
      ),

      // Chat / Conversation
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return ChatPage(conversationId: conversationId);
        },
      ),

      // Story Viewer
      GoRoute(
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
        path: AppRoutes.followers,
        name: 'followers',
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ProfilePage(username: username);
        },
      ),

      // Following List
      GoRoute(
        path: AppRoutes.following,
        name: 'following',
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ProfilePage(username: username);
        },
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
