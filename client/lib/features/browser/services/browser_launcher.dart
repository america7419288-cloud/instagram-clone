import 'package:flutter/material.dart';
import '../screens/in_app_browser_screen.dart';
import '../models/browser_session.dart';

class BrowserLauncher {
  /// Call this from anywhere in the app
  static void open({
    required BuildContext context,
    required String url,
    String? title,
    bool isAd = false,
    String? adSource,
    String? adCampaignId,
    bool fullScreen = false,
  }) {
    final uri = _normalizeUrl(url);

    final session = BrowserSession(
      url: uri,
      title: title ?? uri,
      isAd: isAd,
      adSource: adSource,
      adCampaignId: adCampaignId,
    );

    if (fullScreen) {
      Navigator.of(context).push(
        _BrowserRoute(session: session),
      );
    } else {
      _showAsBottomSheet(context, session);
    }
  }

  static String _normalizeUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://$url';
  }

  static void _showAsBottomSheet(
    BuildContext context,
    BrowserSession session,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: InAppBrowserScreen(session: session),
      ),
    );
  }
}

class _BrowserRoute extends PageRouteBuilder {
  final BrowserSession session;

  _BrowserRoute({required this.session})
    : super(
        pageBuilder: (ctx, anim, _) =>
          InAppBrowserScreen(session: session),
        transitionsBuilder: (ctx, anim, _, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      );
}
