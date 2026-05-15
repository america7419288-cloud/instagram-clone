import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../core/storage/chat_local_db.dart';
import '../../../../core/api/chat_api.dart';
import '../../data/repositories/message_repository.dart';

// Repository Provider
final chatApiProvider = Provider<ChatApi>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return ChatApi(dio);
});

final chatLocalDbProvider = Provider<ChatLocalDb>((ref) => ChatLocalDb());

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final api = ref.watch(chatApiProvider);
  final socket = ref.watch(socketServiceProvider);
  final localDb = ref.watch(chatLocalDbProvider);
  return MessageRepository(api: api, socket: socket, localDb: localDb);
});

// Initialization Provider (to ensure DB is ready)
final chatInitProvider = FutureProvider<void>((ref) async {
  final localDb = ref.watch(chatLocalDbProvider);
  await localDb.initialize();
});
