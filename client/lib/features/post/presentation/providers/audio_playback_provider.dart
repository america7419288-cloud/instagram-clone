import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayingPostIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPlaying(String? postId) {
    state = postId;
  }
}

final playingPostIdProvider = NotifierProvider<PlayingPostIdNotifier, String?>(() => PlayingPostIdNotifier());

class GlobalMuteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggleMute() {
    state = !state;
  }
}

final globalMuteProvider = NotifierProvider<GlobalMuteNotifier, bool>(() => GlobalMuteNotifier());
