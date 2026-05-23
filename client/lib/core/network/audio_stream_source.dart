import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:instagram_client/core/constants/app_constants.dart';

class BackendStreamAudioSource extends StreamAudioSource {
  static final _ytClient = yt.YoutubeExplode();
  static bool _isRateLimited = false;
  static DateTime? _lastRateLimitTime;
  
  final Dio dio;
  final String videoId;

  BackendStreamAudioSource(this.dio, this.videoId);

  static final List<String> _invidiousInstances = [
    'https://yewtu.be',
    'https://invidious.nerdvpn.de',
    'https://invidious.privacydev.net',
    'https://invidious.lunar.icu',
    'https://inv.tux.im',
    'https://invidious.flokinet.to'
  ];

  /// Resolves the best playable AudioSource natively on the client.
  /// Bypasses local byte-streaming servers to prevent socket timeouts on emulators.
  static Future<AudioSource> getPlayableSource(Dio dio, String videoId) async {
    // Check if we are currently flagged as rate-limited to avoid blocking retries
    if (_isRateLimited && _lastRateLimitTime != null) {
      final difference = DateTime.now().difference(_lastRateLimitTime!);
      if (difference.inMinutes < 5) {
        print('⏳ Skipping client extraction: YouTube rate limit active (flagged ${difference.inSeconds}s ago). Trying Invidious resolution.');
        final invidiousSource = await _fetchInvidiousSource(dio, videoId);
        if (invidiousSource != null) return invidiousSource;
        
        print('⚠️ Invidious resolution failed. Routing directly to backend fallback.');
        return _getDirectBackendFallback(dio, videoId);
      } else {
        // Reset rate limit flag after 5 minutes
        _isRateLimited = false;
        _lastRateLimitTime = null;
      }
    }

    try {
      print('🎵 Resolving dynamic progressive MP4 stream for videoId: $videoId');
      final manifest = await _ytClient.videos.streams.getManifest(videoId);
      
      final mp4Streams = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4');
      final audioStream = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : manifest.audioOnly.withHighestBitrate();
          
      final audioUrl = audioStream.url.toString();
      print('🎵 Direct Audio URL resolved. Playing natively via AudioSource.uri');
      
      return AudioSource.uri(
        Uri.parse(audioUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('limit') || errorStr.contains('rate') || errorStr.contains('suspicious') || errorStr.contains('too many requests')) {
        print('🚨 YouTube rate-limiting detected! Flagging client as rate-limited.');
        _isRateLimited = true;
        _lastRateLimitTime = DateTime.now();
      }

      print('⚠️ Native URI extraction failed: $e. Trying Invidious resolution...');
      final invidiousSource = await _fetchInvidiousSource(dio, videoId);
      if (invidiousSource != null) return invidiousSource;

      print('⚠️ Invidious resolution failed. Falling back to direct backend URL...');
      return _getDirectBackendFallback(dio, videoId);
    }
  }

  static Future<AudioSource?> _fetchInvidiousSource(Dio dio, String videoId) async {
    for (final instance in _invidiousInstances) {
      try {
        print('🌐 Client trying Invidious instance: $instance for videoId: $videoId');
        final response = await dio.get(
          '$instance/api/v1/videos/$videoId',
          options: Options(
            extra: const {'skipAuthInterceptor': true}, // Prevents leaking JWT auth to third-party public instances
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data != null && data['adaptiveFormats'] != null) {
            final List<dynamic> formats = data['adaptiveFormats'];
            // Find an audio/mp4 progressive stream
            final audioFormat = formats.firstWhere(
              (f) => f['mimeType'] != null && 
                     f['mimeType'].toString().startsWith('audio/mp4') && 
                     f['url'] != null,
              orElse: () => null,
            );

            if (audioFormat != null && audioFormat['url'] != null) {
              final streamUrl = audioFormat['url'].toString();
              print('✅ Client extracted stream successfully via Invidious ($instance)');
              return AudioSource.uri(
                Uri.parse(streamUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
              );
            }
          }
        }
      } catch (e) {
        print('⚠️ Failed to fetch stream from Invidious instance $instance: $e');
      }
    }
    return null;
  }

  static Future<AudioSource> _getDirectBackendFallback(Dio dio, String videoId) async {
    final fallbackUrl = '${dio.options.baseUrl}/music/stream/$videoId';
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      
      return AudioSource.uri(
        Uri.parse(fallbackUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (innerErr) {
      print('❌ Direct fallback initialization failed: $innerErr. Returning fallback proxy source.');
      return BackendStreamAudioSource(dio, videoId);
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      print('🎵 Dynamic Client-Side Extraction for videoId: $videoId');
      
      // 1. Resolve direct progressive MP4/AAC audio stream URL using shared youtube_explode client
      final manifest = await _ytClient.videos.streams.getManifest(videoId);
      
      // Filter specifically for MP4 (AAC) container streams to guarantee progressive player compatibility
      final mp4Streams = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4');
      final audioStream = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : manifest.audioOnly.withHighestBitrate();
          
      print('🎵 Direct Audio URL resolved successfully.');
      
      // 2. Resolve the stream natively via youtube_explode to guarantee matching User-Agent & signatures
      final stream = _ytClient.videos.streams.get(audioStream);
      final finalStream = (start != null && start > 0) ? _skipBytes(stream, start) : stream;

      final containerName = audioStream.container.name.toLowerCase();
      final contentType = containerName == 'webm' 
          ? 'audio/webm' 
          : (containerName == 'mp3' ? 'audio/mpeg' : 'audio/mp4');

      print('🎵 Native stream resolved. contentType=$contentType, offset=${start ?? 0}');

      return StreamAudioResponse(
        sourceLength: audioStream.size.totalBytes,
        contentLength: audioStream.size.totalBytes - (start ?? 0),
        offset: start ?? 0,
        stream: finalStream,
        contentType: contentType,
      );
    } catch (clientError) {
      print('⚠️ Client-side extraction failed: $clientError. Falling back to backend stream...');
      
      // FALLBACK: Use the original backend proxy stream if client-side extraction fails!
      try {
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

        return StreamAudioResponse(
          sourceLength: _parseTotalLength(contentRange) ?? int.tryParse(contentLength ?? '') ?? 0,
          contentLength: int.tryParse(contentLength ?? '') ?? 0,
          offset: start ?? 0,
          stream: response.data.stream,
          contentType: 'audio/mpeg',
        );
      } catch (e) {
        print('❌ AudioSource Fallback Error: $e');
        rethrow;
      }
    }
  }

  Stream<List<int>> _skipBytes(Stream<List<int>> stream, int bytesToSkip) async* {
    int skipped = 0;
    await for (final chunk in stream) {
      if (skipped >= bytesToSkip) {
        yield chunk;
      } else if (skipped + chunk.length > bytesToSkip) {
        yield chunk.sublist(bytesToSkip - skipped);
        skipped = bytesToSkip;
      } else {
        skipped += chunk.length;
      }
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
