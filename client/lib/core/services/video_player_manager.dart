import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerManager {
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final List<String> _lruList = [];
  static const int _maxPoolSize = 5;

  Future<VideoPlayerController> getController(String url) async {
    if (_controllers.containsKey(url)) {
      // Move to front (most recently used)
      _lruList.remove(url);
      _lruList.insert(0, url);
      
      final controller = _controllers[url]!;
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      return controller;
    }

    // Create new controller
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    
    // Manage pool size
    if (_lruList.length >= _maxPoolSize) {
      final oldestUrl = _lruList.removeLast();
      final oldestController = _controllers.remove(oldestUrl);
      await oldestController?.dispose();
      debugPrint('🎬 Disposed oldest video controller: $oldestUrl');
    }

    _controllers[url] = controller;
    _lruList.insert(0, url);
    
    debugPrint('🎬 Initializing new video controller: $url');
    await controller.initialize();
    return controller;
  }

  /// Optional: Pre-initialize a video to reduce wait time
  Future<void> preload(String url) async {
    if (!_controllers.containsKey(url)) {
      await getController(url);
    }
  }

  /// Dispose all controllers (e.g., on logout or deep cleanup)
  Future<void> disposeAll() async {
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
    _lruList.clear();
  }
}
