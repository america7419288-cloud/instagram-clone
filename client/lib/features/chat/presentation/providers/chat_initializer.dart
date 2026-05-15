import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/socket/socket_provider.dart';
import 'chat_providers.dart';
import 'chat_notifiers.dart';
import 'presence_provider.dart';

final chatServiceInitializerProvider = Provider<ChatServiceInitializer>((ref) {
  return ChatServiceInitializer(ref);
});

class ChatServiceInitializer {
  final Ref _ref;

  ChatServiceInitializer(this._ref) {
    _init();
  }

  Future<void> _init() async {
    // 1. Ensure local DB is ready
    await _ref.read(chatInitProvider.future);
    
    // 2. Connect socket
    _ref.read(socketServiceProvider).connect();
    
    // 3. Warm up inbox
    _ref.read(inboxProvider.notifier).loadConversations();
    
    // 4. Initialize presence tracking
    _ref.read(presenceProvider);
  }
  
  void refresh() {
    _ref.read(inboxProvider.notifier).loadConversations();
  }
}
