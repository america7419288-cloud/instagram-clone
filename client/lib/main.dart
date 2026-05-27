// lib/main.dart - Force recompile

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_handler.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/chat/presentation/providers/chat_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Edge-to-Edge Display ──────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ─── Lock to portrait ────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ─── Initialize Firebase ─────────────────────────────
  try {
    if (kIsWeb) {
      debugPrint('ℹ️ Firebase initialization skipped on Web (options missing)');
    } else {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');

      // ─── Register background message handler ───────────
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    }
  } catch (e) {
    debugPrint('⚠️ Firebase init error: $e');
  }

  runApp(
    const ProviderScope(
      child: InstagramCloneApp(),
    ),
  );
}

class InstagramCloneApp extends ConsumerWidget {
  const InstagramCloneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeState = ref.watch(themeProvider);

    // Show loading while theme loads from storage
    if (themeState.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CupertinoActivityIndicator(radius: 12),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Instagram Clone',
      debugShowCheckedModeBanner: false,

      // ⭐ iOS Design Theme
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: themeState.themeMode,
      routerConfig: router,
      
      builder: (context, child) {
        // Initialize chat service
        ref.watch(chatServiceInitializerProvider);
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Apply Global No-Ripple behavior & reactive status bar overlays
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
              decorationColor: Colors.transparent,
              decorationThickness: 0,
            ),
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(),
                overscroll: false,
              ),
              child: NotificationHandler(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
