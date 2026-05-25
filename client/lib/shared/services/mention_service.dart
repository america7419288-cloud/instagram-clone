import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class MentionService {
  final DioClient _dioClient;

  MentionService(this._dioClient);

  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    String context = 'general',
    String? contextId,
  }) async {
    try {
      final response = await _dioClient.get(
        '/mentions/search',
        queryParameters: {
          'q': query,
          'context': context,
          if (contextId != null && contextId.isNotEmpty) 'contextId': contextId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }
      return [];
    } catch (e) {
      // Return empty list on failure, non-blocking
      return [];
    }
  }
}

final mentionServiceProvider = Provider<MentionService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return MentionService(dioClient);
});
