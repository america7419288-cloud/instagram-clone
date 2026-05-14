import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(() {
      return ConnectivityNotifier();
    });

class ConnectivityNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    // Initial check
    Future.microtask(() => _checkConnection());
    
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnection();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return true;
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      final isConnected =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      if (isConnected != state) {
        state = isConnected;
      }
    } catch (_) {
      if (state) {
        state = false;
      }
    }
  }
}

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return IgnorePointer(
      ignoring: isOnline,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        offset: isOnline ? const Offset(0, -1) : Offset.zero,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: topPadding + 8,
              bottom: 10,
              left: 16,
              right: 16,
            ),
            color: const Color(0xFF323232),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

