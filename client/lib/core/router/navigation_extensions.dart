import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeGoRouterNavigation on BuildContext {
  void pushIfNotCurrent(String location) {
    if (GoRouterState.of(this).uri.toString() == location) return;

    if (_isShellRoute(location)) {
      go(location);
      return;
    }

    push(location);
  }

  bool _isShellRoute(String location) {
    return location == '/home' ||
        location == '/search' ||
        location == '/notifications' ||
        location == '/messages' ||
        location.startsWith('/messages/') ||
        location.startsWith('/profile/');
  }
}
