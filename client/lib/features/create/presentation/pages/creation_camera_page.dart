// lib/features/create/presentation/pages/creation_camera_page.dart

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'media_picker_page.dart';
import 'post_editor_page.dart';
import 'story_editor_page.dart';
import 'reel_editor_page.dart';
import 'package:colorfilter_generator/presets.dart';


enum CreationMode { post, story, reel }

// Timer durations cycle: off → 3s → 10s → off
enum TimerDuration { off, three, ten }

class CreationCameraPage extends StatefulWidget {
  final CreationMode initialMode;
  const CreationCameraPage({super.key, this.initialMode = CreationMode.post});

  @override
  State<CreationCameraPage> createState() => _CreationCameraPageState();
}

class _CreationCameraPageState extends State<CreationCameraPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late CreationMode _currentMode;

  // Camera
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  bool _permissionsDenied = false;
  bool _isPermanentlyDenied = false;
  AssetEntity? _latestAsset;

  // Recording
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  static const int _maxRecordingSeconds = 90;
  Timer? _recordingTimer;

  // Timer countdown
  TimerDuration _timerDuration = TimerDuration.off;
  bool _isCountingDown = false;
  int _countdownValue = 0;
  Timer? _countdownTimer;

  // Story mode extras
  bool _isBoomerangMode = false;

  // Reel mode speed
  final List<double> _reelSpeeds = [0.3, 0.5, 1.0, 2.0, 3.0];
  final List<String> _reelSpeedLabels = ['0.3×', '0.5×', '1×', '2×', '3×'];
  int _reelSpeedIdx = 2; // 1× default

  // Zoom
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  // Animations
  late AnimationController _shutterPulseCtrl;
  late Animation<double> _shutterPulse;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Premium Custom State variables
  bool _isStartingRecording = false;     // Video recording race lock
  bool _isHDREnabled = false;            // Hardware-oriented HDR mode
  int _activeLiveFilterIdx = 0;          // Active live filter preset index
  bool _showLiveFiltersSelector = false; // Horizontal filter picker overlay
  bool _isLayoutMode = false;            // STORY layout split mode
  int _layoutSelectedGrid = 0;           // Grid style: 0=2x2, 1=1x2 split
  bool _isAlignEnabled = false;          // REEL align ghost watermark
  File? _lastCapturedFileForAlign;       // Saved frame for align ghosting

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMode = widget.initialMode;

    _shutterPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _shutterPulse = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _shutterPulseCtrl, curve: Curves.easeInOut),
    );

    _initCamera();
    _loadLatestAsset();
  }

  Future<void> _loadLatestAsset() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        final paths = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          onlyAll: true,
        );
        if (paths.isNotEmpty) {
          final assets = await paths[0].getAssetListRange(start: 0, end: 1);
          if (assets.isNotEmpty && mounted) {
            setState(() => _latestAsset = assets[0]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading latest asset: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _audioPlayer.dispose();
    _shutterPulseCtrl.dispose();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cam.description);
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _cameras = null;
      _isCameraInitialized = false;
      _permissionsDenied = false;
      _isPermanentlyDenied = false;
    });

    try {
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (camStatus.isDenied || micStatus.isDenied) {
        if (mounted) {
          setState(() {
            _cameras = [];
            _isCameraInitialized = false;
            _permissionsDenied = true;
            _isPermanentlyDenied =
                camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied;
          });
        }
        return;
      }

      final cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Camera timeout'),
      );

      if (mounted) {
        setState(() => _cameras = cameras);
        if (cameras.isNotEmpty) {
          _onNewCameraSelected(cameras[_selectedCameraIndex]);
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
      if (mounted) setState(() { _cameras = []; _isCameraInitialized = false; });
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription desc) async {
    await _controller?.dispose();

    final cam = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = cam;

    cam.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cam.initialize();
      await cam.setFlashMode(_flashMode);
      _minZoom = await cam.getMinZoomLevel();
      _maxZoom = await cam.getMaxZoomLevel();
      _currentZoom = _minZoom;
      if (mounted) setState(() => _isCameraInitialized = true);
    } on CameraException catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Mode ──────────────────────────────────────────────────
  void _onModeChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMode = CreationMode.values[index];
      _isBoomerangMode = false;
    });
  }

  // ── Camera controls ───────────────────────────────────────
  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _onNewCameraSelected(_cameras![_selectedCameraIndex]);
    HapticFeedback.mediumImpact();
  }

  void _toggleFlash() {
    if (_controller == null) return;
    final modes = [FlashMode.off, FlashMode.always, FlashMode.auto];
    final nextIdx = (modes.indexOf(_flashMode) + 1) % modes.length;
    setState(() => _flashMode = modes[nextIdx]);
    _controller!.setFlashMode(modes[nextIdx]);
    HapticFeedback.lightImpact();
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.always: return LucideIcons.zap;
      case FlashMode.auto:   return LucideIcons.zap_off;
      default:               return LucideIcons.zap;
    }
  }

  Color get _flashColor {
    switch (_flashMode) {
      case FlashMode.always: return const Color(0xFFFFD60A);
      case FlashMode.auto:   return Colors.white70;
      default:               return Colors.white;
    }
  }

  String get _flashLabel {
    switch (_flashMode) {
      case FlashMode.always: return 'On';
      case FlashMode.auto:   return 'Auto';
      default:               return 'Off';
    }
  }

  // ── Timer ─────────────────────────────────────────────────
  void _cycleTimer() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_timerDuration) {
        case TimerDuration.off:   _timerDuration = TimerDuration.three; break;
        case TimerDuration.three: _timerDuration = TimerDuration.ten;   break;
        case TimerDuration.ten:   _timerDuration = TimerDuration.off;   break;
      }
    });
  }

  int get _timerSeconds {
    switch (_timerDuration) {
      case TimerDuration.three: return 3;
      case TimerDuration.ten:   return 10;
      default: return 0;
    }
  }

  String get _timerLabel {
    switch (_timerDuration) {
      case TimerDuration.three: return '3s';
      case TimerDuration.ten:   return '10s';
      default: return 'Off';
    }
  }

  bool get _timerActive => _timerDuration != TimerDuration.off;

  void _startWithTimer(VoidCallback action) {
    if (_timerSeconds == 0) { action(); return; }
    HapticFeedback.heavyImpact();
    setState(() { _isCountingDown = true; _countdownValue = _timerSeconds; });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final next = _countdownValue - 1;
      HapticFeedback.selectionClick();
      if (next <= 0) {
        t.cancel();
        setState(() { _isCountingDown = false; _countdownValue = 0; });
        action();
      } else {
        setState(() => _countdownValue = next);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() { _isCountingDown = false; _countdownValue = 0; });
  }

  // ── Zoom ──────────────────────────────────────────────────
  void _handleZoom(ScaleUpdateDetails details) {
    final zoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = zoom);
    _controller?.setZoomLevel(zoom);
  }

  // ── Custom Interactive Toggle Controls ───────────────────────
  void _toggleHDR() async {
    if (_controller == null || !_isCameraInitialized) return;
    HapticFeedback.mediumImpact();
    setState(() => _isHDREnabled = !_isHDREnabled);
    try {
      if (_isHDREnabled) {
        await _controller!.setExposureMode(ExposureMode.auto);
        await _controller!.setExposureOffset(-0.3);
      } else {
        await _controller!.setExposureOffset(0.0);
      }
    } catch (e) {
      debugPrint('HDR toggle error: $e');
    }
  }

  void _toggleLayout() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (!_isLayoutMode) {
        _isLayoutMode = true;
        _layoutSelectedGrid = 0;
      } else if (_layoutSelectedGrid == 0) {
        _layoutSelectedGrid = 1;
      } else {
        _isLayoutMode = false;
      }
    });
  }

  void _toggleAlign() {
    HapticFeedback.mediumImpact();
    setState(() => _isAlignEnabled = !_isAlignEnabled);
  }

  void _toggleLiveFilters() {
    HapticFeedback.mediumImpact();
    setState(() => _showLiveFiltersSelector = !_showLiveFiltersSelector);
  }


  // ── Capture ───────────────────────────────────────────────
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _isRecording) return;
    if (_isCountingDown) { _cancelCountdown(); return; }

    _startWithTimer(() async {
      try {
        final file = await _controller!.takePicture();
        _playShutterSound();
        HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _lastCapturedFileForAlign = File(file.path);
          });
          _navigateToEditor(File(file.path));
        }
      } catch (e) { debugPrint('Capture error: $e'); }
    });
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isCameraInitialized || _isRecording || _isStartingRecording) return;
    if (_isCountingDown) { _cancelCountdown(); return; }

    _startWithTimer(() async {
      try {
        setState(() { _isStartingRecording = true; });
        await _controller!.startVideoRecording();
        HapticFeedback.heavyImpact();
        setState(() { 
          _isRecording = true; 
          _isStartingRecording = false;
          _recordingProgress = 0.0; 
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          final progress = (t.tick * 100) / (_maxRecordingSeconds * 1000);
          if (progress >= 1.0) {
            _stopVideoRecording();
          } else {
            setState(() => _recordingProgress = progress);
          }
        });
      } catch (e) { 
        debugPrint('Recording error: $e'); 
        setState(() { _isStartingRecording = false; });
      }
    });
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null) return;

    // Handle race condition: wait if starting recording is still in progress
    if (_isStartingRecording) {
      int retries = 0;
      while (_isStartingRecording && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
    }

    if (!_isRecording && !_controller!.value.isRecordingVideo) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      final file = await _controller!.stopVideoRecording();
      HapticFeedback.selectionClick();
      setState(() { 
        _isRecording = false; 
        _isStartingRecording = false;
        _recordingProgress = 0.0; 
        _lastCapturedFileForAlign = File(file.path);
      });
      if (mounted) _navigateToEditor(File(file.path));
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() { 
        _isRecording = false; 
        _isStartingRecording = false;
        _recordingProgress = 0.0; 
      });
    }
  }

  // Reel mode: tap to start/stop
  void _handleReelCapture() {
    if (_isCountingDown) { _cancelCountdown(); return; }
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  Future<void> _playShutterSound() async {
    try {
      await _audioPlayer.setAsset(AppAssets.shutter);
      await _audioPlayer.play();
    } catch (_) {}
  }

  void _navigateToEditor(File file) {
    Widget editor;
    switch (_currentMode) {
      case CreationMode.post:  editor = PostEditorPage(files: [file]); break;
      case CreationMode.story: editor = StoryEditorPage(file: file);   break;
      case CreationMode.reel:  editor = ReelEditorPage(file: file);    break;
    }
    Navigator.push(context, CupertinoPageRoute(builder: (_) => editor));
  }

  void _openGallery() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MediaPickerPage(
          createType: _currentMode == CreationMode.post
              ? CreateType.post
              : _currentMode == CreationMode.reel
                  ? CreateType.reel
                  : CreateType.story,
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview with pinch-to-zoom
          _buildCameraPreview(),

          // 2. Countdown overlay
          if (_isCountingDown) _buildCountdownOverlay(),

          // 3. Top bar
          _buildTopBar(safeTop),

          // 4. Mode-specific right tools
          _buildRightTools(safeTop),

          // 5. Bottom controls
          _buildBottomControls(safeBot),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: GestureDetector(
        onScaleStart: (d) => _baseZoom = _currentZoom,
        onScaleUpdate: _handleZoom,
        child: _isCameraInitialized && _controller != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: _buildLiveFilter(),
                    child: CameraPreview(_controller!),
                  ),
                  _buildAlignOverlay(),
                  _buildLayoutGuides(),
                ],
              )
            : Container(
                color: Colors.black,
                child: Center(
                  child: _cameras == null
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.camera_off,
                                color: Colors.white24, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _cameras!.isEmpty
                                  ? (_permissionsDenied
                                      ? 'Camera permission denied'
                                      : 'No camera found')
                                  : 'Initializing...',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            if (_cameras!.isEmpty) ...[
                              const SizedBox(height: 20),
                              CupertinoButton(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                                onPressed: _isPermanentlyDenied
                                    ? openAppSettings
                                    : _initCamera,
                                child: Text(
                                  _isPermanentlyDenied ? 'Open Settings' : 'Retry',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  ColorFilter _buildLiveFilter() {
    if (_activeLiveFilterIdx == 0 || _activeLiveFilterIdx >= presetFiltersList.length) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
    final preset = presetFiltersList[_activeLiveFilterIdx];
    return ColorFilter.matrix(preset.matrix);
  }

  Widget _buildLayoutGuides() {
    if (!_isLayoutMode) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (_layoutSelectedGrid == 0) ...[
              // 2x2 Grid guides
              Align(
                alignment: Alignment.center,
                child: Container(width: double.infinity, height: 1.5, color: Colors.white30),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(width: 1.5, height: double.infinity, color: Colors.white30),
              ),
            ] else ...[
              // 1x2 split guide
              Align(
                alignment: Alignment.center,
                child: Container(width: 1.5, height: double.infinity, color: Colors.white30),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildAlignOverlay() {
    if (!_isAlignEnabled) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.45,
          child: _lastCapturedFileForAlign != null
              ? Image.file(_lastCapturedFileForAlign!, fit: BoxFit.cover)
              : ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      color: Colors.white.withOpacity(0.08),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.layers, color: Colors.white.withOpacity(0.4), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Align ghost layer active\nTake a capture first to see it overlayed',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SF-Pro',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _cancelCountdown,
        child: Container(
          color: Colors.black54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_countdownValue),
                tween: Tween(begin: 1.4, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  '$_countdownValue',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to cancel',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(double safeTop) {
    return Positioned(
      top: safeTop + 8,
      left: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                // Close
                _GlassIconButton(
                  iconPath: AppAssets.close,
                  label: '',
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                // Flash — hidden for REEL front-cam typically, but show always
                _GlassIconButton(
                  icon: _flashIcon,
                  color: _flashColor,
                  label: _flashLabel,
                  onTap: _toggleFlash,
                ),
                const SizedBox(width: 4),
                // Mode-specific top-right button
                if (_currentMode == CreationMode.post)
                  _GlassIconButton(
                    icon: LucideIcons.settings,
                    label: '',
                    onTap: () {},
                  ),
                if (_currentMode == CreationMode.story)
                  _GlassIconButton(
                    icon: LucideIcons.sparkles,
                    label: '',
                    onTap: () {},
                  ),
                if (_currentMode == CreationMode.reel)
                  _GlassIconButton(
                    icon: LucideIcons.music,
                    label: '',
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightTools(double safeTop) {
    return Positioned(
      right: 12,
      top: safeTop + 72,
      bottom: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _getModeRightTools(),
      ),
    );
  }

  List<Widget> _getModeRightTools() {
    switch (_currentMode) {
      case CreationMode.post:
        return [
          _RightToolBtn(
            icon: LucideIcons.refresh_cw,
            label: 'Flip',
            onTap: _toggleCamera,
          ),
          _RightToolBtn(
            icon: LucideIcons.timer,
            label: _timerLabel,
            active: _timerActive,
            onTap: _cycleTimer,
          ),
          _RightToolBtn(
            icon: LucideIcons.aperture,
            label: 'HDR',
            active: _isHDREnabled,
            onTap: _toggleHDR,
          ),
          _RightToolBtn(
            icon: LucideIcons.image,
            label: 'Live',
            onTap: () {},
          ),
        ];

      case CreationMode.story:
        return [
          _RightToolBtn(
            icon: LucideIcons.refresh_cw,
            label: 'Flip',
            onTap: _toggleCamera,
          ),
          _RightToolBtn(
            icon: LucideIcons.timer,
            label: _timerLabel,
            active: _timerActive,
            onTap: _cycleTimer,
          ),
          _RightToolBtn(
            icon: LucideIcons.infinity,
            label: 'Boomerang',
            active: _isBoomerangMode,
            onTap: () {
              setState(() => _isBoomerangMode = !_isBoomerangMode);
              HapticFeedback.selectionClick();
            },
          ),
          _RightToolBtn(
            icon: LucideIcons.layout_grid,
            label: 'Layout',
            active: _isLayoutMode,
            onTap: _toggleLayout,
          ),
          _RightToolBtn(
            icon: LucideIcons.sparkles,
            label: 'Filter',
            active: _showLiveFiltersSelector,
            onTap: _toggleLiveFilters,
          ),
        ];

      case CreationMode.reel:
        return [
          _RightToolBtn(
            icon: LucideIcons.refresh_cw,
            label: 'Flip',
            onTap: _toggleCamera,
          ),
          _RightToolBtn(
            icon: LucideIcons.timer,
            label: _timerLabel,
            active: _timerActive,
            onTap: _cycleTimer,
          ),
          // Speed pill for reel
          _SpeedToolBtn(
            speeds: _reelSpeedLabels,
            selectedIdx: _reelSpeedIdx,
            onTap: () {
              setState(() =>
                  _reelSpeedIdx = (_reelSpeedIdx + 1) % _reelSpeeds.length);
              HapticFeedback.selectionClick();
            },
          ),
          _RightToolBtn(
            icon: LucideIcons.zap,
            label: 'Effects',
            active: _showLiveFiltersSelector,
            onTap: _toggleLiveFilters,
          ),
          _RightToolBtn(
            icon: LucideIcons.layers,
            label: 'Align',
            active: _isAlignEnabled,
            onTap: _toggleAlign,
          ),
        ];
    }
  }

  Widget _buildBottomControls(double safeBot) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.88),
              Colors.black.withOpacity(0.0),
            ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, safeBot + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode-specific hint
            _buildModeHint(),
            const SizedBox(height: 12),
            // Live filters horizontal selector panel
            _buildLiveFiltersSelector(),
            // Capture row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _GalleryThumb(asset: _latestAsset, onTap: _openGallery),
                _buildCaptureButton(),
                // Reel speed indicator OR empty space
                if (_currentMode == CreationMode.reel)
                  _buildReelSpeedBadge()
                else
                  const SizedBox(width: 52),
              ],
            ),
            const SizedBox(height: 20),
            // Mode selector
            _ModeSelectorBar(
              modes: CreationMode.values,
              current: _currentMode,
              onModeChanged: _onModeChanged,
            ),
            SizedBox(height: safeBot > 0 ? 4 : 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFiltersSelector() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: _showLiveFiltersSelector
          ? Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: presetFiltersList.length,
                itemBuilder: (context, idx) {
                  final filter = presetFiltersList[idx];
                  final isSelected = _activeLiveFilterIdx == idx;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeLiveFilterIdx = idx);
                    },
                    child: AnimatedScale(
                      scale: isSelected ? 1.06 : 0.94,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [Color(0xFF00C6FF), Color(0xFF0095F6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : Colors.white24,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF0095F6).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white12,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    filter.name.substring(0, math.min(filter.name.length, 2)).toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'SF-Pro',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              filter.name,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0095F6) : Colors.white60,
                                fontSize: 9.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                fontFamily: 'SF-Pro',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildModeHint() {
    String hint;
    switch (_currentMode) {
      case CreationMode.post:
        hint = _isRecording
            ? 'Recording… tap to stop'
            : 'TAP for photo  ·  HOLD for video';
        break;
      case CreationMode.story:
        hint = _isBoomerangMode
            ? 'Boomerang — TAP to record'
            : _isRecording
                ? 'Recording… release to stop'
                : 'TAP for photo  ·  HOLD for video';
        break;
      case CreationMode.reel:
        hint = _isRecording
            ? 'Recording ${(_reelSpeedLabels[_reelSpeedIdx])} — TAP to stop'
            : 'TAP to start recording';
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        hint,
        key: ValueKey(hint),
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    // Reel: single tap to start/stop
    if (_currentMode == CreationMode.reel) {
      return GestureDetector(
        onTap: _handleReelCapture,
        child: AnimatedBuilder(
          animation: _shutterPulse,
          builder: (_, child) => Transform.scale(
            scale: _isRecording ? _shutterPulse.value : 1.0,
            child: child,
          ),
          child: _CaptureButton(
            isRecording: _isRecording,
            progress: _recordingProgress,
            mode: _currentMode,
          ),
        ),
      );
    }

    // Post & Story: tap for photo, hold for video
    return GestureDetector(
      onTap: _takePicture,
      onLongPressStart: (_) => _startVideoRecording(),
      onLongPressEnd: (_) { if (_isRecording) _stopVideoRecording(); },
      child: AnimatedBuilder(
        animation: _shutterPulse,
        builder: (_, child) => Transform.scale(
          scale: _isRecording ? _shutterPulse.value : 1.0,
          child: child,
        ),
        child: _CaptureButton(
          isRecording: _isRecording,
          progress: _recordingProgress,
          mode: _currentMode,
        ),
      ),
    );
  }

  Widget _buildReelSpeedBadge() {
    return GestureDetector(
      onTap: () {
        if (!_isRecording) {
          setState(() =>
              _reelSpeedIdx = (_reelSpeedIdx + 1) % _reelSpeeds.length);
          HapticFeedback.selectionClick();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: _isRecording
              ? const Color(0xFFED4956).withOpacity(0.3)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isRecording
                ? const Color(0xFFED4956)
                : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _reelSpeedLabels[_reelSpeedIdx],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Mode Selector Bar ──────────────────────────────────────
class _ModeSelectorBar extends StatelessWidget {
  final List<CreationMode> modes;
  final CreationMode current;
  final ValueChanged<int> onModeChanged;

  const _ModeSelectorBar({
    required this.modes,
    required this.current,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width - 48;
    final itemWidth = totalWidth / modes.length;
    final selectedIdx = modes.indexOf(current);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: List.generate(modes.length, (index) {
              final mode = modes[index];
              final isSelected = current == mode;
              return GestureDetector(
                onTap: () => onModeChanged(index),
                child: SizedBox(
                  width: itemWidth,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                      child: Text(mode.name.toUpperCase()),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Sliding underline
        AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment(
            selectedIdx == 0
                ? -1.0
                : selectedIdx == modes.length - 1
                    ? 1.0
                    : 0.0,
            0,
          ),
          child: Container(
            width: itemWidth * 0.32,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Premium Capture Button ─────────────────────────────────
class _CaptureButton extends StatelessWidget {
  final bool isRecording;
  final double progress;
  final CreationMode mode;

  const _CaptureButton({
    required this.isRecording,
    required this.progress,
    required this.mode,
  });

  // Different accent colors per mode
  Color get _activeColor {
    switch (mode) {
      case CreationMode.post:  return const Color(0xFFED4956);
      case CreationMode.story: return const Color(0xFF833AB4);
      case CreationMode.reel:  return const Color(0xFFFD1D1D);
    }
  }

  Color get _progressEnd {
    switch (mode) {
      case CreationMode.post:  return const Color(0xFFFF6B35);
      case CreationMode.story: return const Color(0xFFFCB045);
      case CreationMode.reel:  return const Color(0xFFF58529);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Progress arc
        SizedBox(
          width: 88,
          height: 88,
          child: CustomPaint(
            painter: _GradientProgressPainter(
              progress: progress,
              isRecording: isRecording,
              startColor: _activeColor,
              endColor: _progressEnd,
            ),
          ),
        ),
        // Outer ring
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: isRecording ? 82 : 76,
          height: isRecording ? 82 : 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isRecording ? 3.5 : 3.0,
            ),
          ),
        ),
        // Inner shape — square when recording, circle when idle
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: isRecording ? 38 : 60,
          height: isRecording ? 38 : 60,
          decoration: BoxDecoration(
            gradient: isRecording
                ? LinearGradient(
                    colors: [_activeColor, _progressEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isRecording ? null : Colors.white,
            borderRadius: BorderRadius.circular(isRecording ? 10 : 40),
            boxShadow: isRecording
                ? [
                    BoxShadow(
                      color: _activeColor.withOpacity(0.55),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  final double progress;
  final bool isRecording;
  final Color startColor;
  final Color endColor;

  _GradientProgressPainter({
    required this.progress,
    required this.isRecording,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRecording) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    final sweepAngle = 2 * math.pi * progress;
    if (sweepAngle <= 0) return;

    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweepAngle,
      colors: [startColor, endColor],
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = shader
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GradientProgressPainter old) =>
      old.progress != progress || old.isRecording != isRecording;
}

// ── Glass Icon Button (top bar) ───────────────────────────
class _GlassIconButton extends StatefulWidget {
  final String? iconPath;
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassIconButton({
    this.iconPath,
    this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: widget.label.isEmpty ? 44 : null,
          height: 44,
          padding: widget.label.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: widget.label.isEmpty
              ? _icon()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(),
                    if (widget.label.isNotEmpty)
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _icon() {
    if (widget.iconPath != null) {
      return SvgPicture.asset(
        widget.iconPath!,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
      );
    }
    return Icon(widget.icon, color: widget.color, size: 20);
  }
}

// ── Right Tool Button ─────────────────────────────────────
class _RightToolBtn extends StatefulWidget {
  final String? iconPath;
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RightToolBtn({
    this.iconPath,
    this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  State<_RightToolBtn> createState() => _RightToolBtnState();
}

class _RightToolBtnState extends State<_RightToolBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.80)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon circle with glassmorphism
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.active
                          ? Colors.white.withOpacity(0.88)
                          : Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.active
                            ? Colors.white
                            : Colors.white.withOpacity(0.12),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: widget.iconPath != null
                          ? SvgPicture.asset(
                              widget.iconPath!,
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                widget.active ? Colors.black : Colors.white,
                                BlendMode.srcIn,
                              ),
                            )
                          : Icon(
                              widget.icon,
                              color: widget.active ? Colors.black : Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.active ? Colors.white : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Speed Tool Button (Reel) ──────────────────────────────
class _SpeedToolBtn extends StatelessWidget {
  final List<String> speeds;
  final int selectedIdx;
  final VoidCallback onTap;

  const _SpeedToolBtn({
    required this.speeds,
    required this.selectedIdx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    speeds[selectedIdx],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gallery Thumbnail ──────────────────────────────────────
class _GalleryThumb extends StatelessWidget {
  final AssetEntity? asset;
  final VoidCallback onTap;
  const _GalleryThumb({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: asset != null
              ? AssetEntityImage(
                  asset!,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(120),
                  fit: BoxFit.cover,
                )
              : const Icon(LucideIcons.image, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
