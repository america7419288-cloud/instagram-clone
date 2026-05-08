import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';

class BackendStreamAudioSource extends StreamAudioSource {
  final Dio dio;
  final String videoId;

  BackendStreamAudioSource(this.dio, this.videoId);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      print('🎵 AudioSource Request: bytes=$start-$end');
      
      final headers = {
        if (start != null || end != null) 'range': 'bytes=${start ?? 0}-${end ?? ''}',
      };

      final response = await dio.get(
        '/music/stream/$videoId',
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );

      final contentRange = response.headers.value('content-range');
      final contentLength = response.headers.value('content-length');
      
      print('🎵 Response: range=$contentRange, length=$contentLength');

      return StreamAudioResponse(
        sourceLength: _parseTotalLength(contentRange) ?? int.tryParse(contentLength ?? '') ?? 0,
        contentLength: int.tryParse(contentLength ?? '') ?? 0,
        offset: start ?? 0,
        stream: response.data.stream,
        contentType: 'audio/mpeg',
      );
    } catch (e) {
      print('❌ AudioSource Error: $e');
      rethrow;
    }
  }

  int? _parseTotalLength(String? contentRange) {
    if (contentRange == null) return null;
    try {
      final parts = contentRange.split('/');
      if (parts.length > 1) {
        return int.tryParse(parts[1]);
      }
    } catch (e) {}
    return null;
  }
}
