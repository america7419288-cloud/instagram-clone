import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/audio_stream_source.dart';
import '../../../../core/design/design_tokens.dart';
import '../../data/models/music_track.dart';

class MusicSelectionPage extends ConsumerStatefulWidget {
  const MusicSelectionPage({super.key});

  @override
  ConsumerState<MusicSelectionPage> createState() => _MusicSelectionPageState();
}

class _MusicSelectionPageState extends ConsumerState<MusicSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<MusicTrack> _tracks = [];
  bool _isLoading = false;
  String? _error;
  String? _playingId;
  bool _isLoadingPreview = false;
  Duration _selectedStartTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _searchMusic('trending');
    
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingId = null);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(MusicTrack track) async {
    if (_playingId == track.id) {
      await _audioPlayer.stop();
      setState(() => _playingId = null);
      return;
    }

    setState(() {
      _playingId = track.id;
      _isLoadingPreview = true;
      _selectedStartTime = Duration.zero; // Reset on new song
    });

    try {
      final dioClient = ref.read(dioClientProvider);
      final source = await BackendStreamAudioSource.getPlayableSource(dioClient.dio, track.id);
      await _audioPlayer.setAudioSource(source);
      
      await _audioPlayer.seek(_selectedStartTime);

      setState(() => _isLoadingPreview = false);

      _audioPlayer.positionStream.listen((pos) {
        final endPosition = _selectedStartTime + const Duration(seconds: 30);
        if (pos >= endPosition) {
          _audioPlayer.stop();
        }
      });

      await _audioPlayer.play();
    } catch (e) {
      setState(() {
        _isLoadingPreview = false;
        _playingId = null;
      });
      print('❌ Error playing audio preview: $e');
      if (mounted) {
        setState(() => _playingId = null);
        String errorMsg = 'Could not play preview';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _searchMusic(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioClientProvider);
      final response = await dio.get('/music/search', queryParameters: {'query': query});

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        setState(() {
          _tracks = data.map((json) => MusicTrack.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load music';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching music: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    final playingTrack = _playingId != null ? _tracks.firstWhere((t) => t.id == _playingId) : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: bgColor.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(LucideIcons.x, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Music',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Search music',
                  placeholderStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                  style: TextStyle(color: textColor),
                  backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
                  onSubmitted: (value) => _searchMusic(value),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : Colors.black))
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: _playingId != null ? 120 : 20),
                            itemCount: _tracks.length,
                            itemBuilder: (context, index) {
                              final track = _tracks[index];
                              final isPlaying = _playingId == track.id;
                              
                              return Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: track.thumbnail != null
                                              ? Image.network(
                                                  track.thumbnail!,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      Container(color: isDark ? Colors.grey[900] : Colors.grey[200], width: 56, height: 56),
                                                )
                                              : Container(color: isDark ? Colors.grey[900] : Colors.grey[200], width: 56, height: 56),
                                        ),
                                        GestureDetector(
                                          onTap: () => _togglePlay(track),
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: _isLoadingPreview && isPlaying
                                                ? const CupertinoActivityIndicator(color: Colors.white, radius: 12)
                                                : Icon(
                                                    isPlaying ? LucideIcons.square : LucideIcons.play,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            track.title,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isPlaying)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(LucideIcons.chart_bar, color: Color(0xFF0095F6), size: 16),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      track.artist,
                                      style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      onPressed: () {
                                        _audioPlayer.stop();
                                        Navigator.pop(context, track.copyWith(startTime: _selectedStartTime));
                                      },
                                      child: Icon(LucideIcons.circle_plus, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                  if (isPlaying)
                                    _buildTrimmerRow(track, isDark),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
          
          if (playingTrack != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: _buildFloatingPlayer(playingTrack, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildTrimmerRow(MusicTrack track, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          StreamBuilder<Duration?>(
            stream: _audioPlayer.durationStream,
            builder: (context, snapshot) {
              final totalDuration = snapshot.data ?? const Duration(minutes: 3);
              final maxStart = totalDuration.inSeconds > 30 ? totalDuration.inSeconds - 30 : 0;
              
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_selectedStartTime),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '30s clip',
                        style: TextStyle(color: const Color(0xFF0095F6), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(40, (i) {
                            final height = 10 + (i % 7) * 4 + (i % 3) * 6.0;
                            return Container(
                              width: 3,
                              height: height,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 48,
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: Colors.transparent,
                            overlayColor: Colors.transparent,
                            thumbShape: _CustomTrimmerThumb(isDark: isDark),
                          ),
                          child: Slider(
                            value: _selectedStartTime.inSeconds.toDouble(),
                            min: 0,
                            max: maxStart.toDouble(),
                            onChanged: (val) {
                              setState(() {
                                _selectedStartTime = Duration(seconds: val.toInt());
                              });
                              _audioPlayer.seek(_selectedStartTime);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPlayer(MusicTrack track, bool isDark) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final relativePos = position.inMilliseconds - _selectedStartTime.inMilliseconds;
                final progress = (relativePos / 30000).clamp(0.0, 1.0);
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0095F6)),
                  minHeight: 2,
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: track.thumbnail != null
                          ? Image.network(track.thumbnail!, width: 40, height: 40, fit: BoxFit.cover)
                          : Container(color: Colors.grey, width: 40, height: 40),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _audioPlayer.playing ? LucideIcons.pause : LucideIcons.play,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        if (_audioPlayer.playing) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.play();
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 4),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF0095F6),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: () {
                        _audioPlayer.stop();
                        Navigator.pop(context, track.copyWith(startTime: _selectedStartTime));
                      },
                      child: const Text(
                        'Select',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomTrimmerThumb extends SliderComponentShape {
  final bool isDark;
  _CustomTrimmerThumb({required this.isDark});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(80, 48);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = const Color(0xFF0095F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rect = Rect.fromCenter(center: center, width: 80, height: 48);
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    canvas.drawRRect(rrect, paint);
    
    canvas.drawRRect(
      rrect, 
      Paint()..color = const Color(0xFF0095F6).withOpacity(0.15)
    );

    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 30, center.dy - 10),
      Offset(center.dx - 30, center.dy + 10),
      handlePaint,
    );
    canvas.drawLine(
      Offset(center.dx + 30, center.dy - 10),
      Offset(center.dx + 30, center.dy + 10),
      handlePaint,
    );
  }
}
