// lib/features/create/presentation/pages/creation_camera_page.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'media_picker_page.dart';
import 'post_editor_page.dart';
import 'story_editor_page.dart';
import 'reel_editor_page.dart';

enum CreationMode { post, story, reel }

class CreationCameraPage extends StatefulWidget {
  final CreationMode initialMode;
  const CreationCameraPage({super.key, this.initialMode = CreationMode.post});

  @override
  State<CreationCameraPage> createState() => _CreationCameraPageState();
}

class _CreationCameraPageState extends State<CreationCameraPage> with WidgetsBindingObserver {
  late CreationMode _currentMode;
  late PageController _modeController;
  
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  bool _permissionsDenied = false;
  bool _isPermanentlyDenied = false;
  AssetEntity? _latestAsset;
  
  // Video Recording
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  static const int _maxRecordingSeconds = 90;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMode = widget.initialMode;
    _modeController = PageController(
      initialPage: _currentMode.index,
      viewportFraction: 0.25,
    );
    _initCamera();
    _loadLatestAsset();
  }

  Future<void> _loadLatestAsset() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          onlyAll: true,
        );
        if (paths.isNotEmpty) {
          final List<AssetEntity> assets = await paths[0].getAssetListRange(
            start: 0,
            end: 1,
          );
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
    _modeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
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
      // Request permissions explicitly for physical devices
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (camStatus.isDenied || micStatus.isDenied) {
        if (mounted) {
          setState(() {
            _cameras = [];
            _isCameraInitialized = false;
            _permissionsDenied = true;
            _isPermanentlyDenied = camStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied;
          });
        }
        return;
      }

      // Add a timeout to availableCameras to prevent infinite loading
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Camera initialization timed out'),
      );
      
      if (mounted) {
        setState(() {
          _cameras = cameras;
        });
        if (cameras.isNotEmpty) {
          _onNewCameraSelected(cameras[_selectedCameraIndex]);
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
      if (mounted) {
        setState(() {
          _cameras = [];
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        debugPrint('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera error $e');
    }
  }

  void _onModeChanged(int index) {
    setState(() {
      _currentMode = CreationMode.values[index];
    });
    HapticFeedback.selectionClick();
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _onNewCameraSelected(_cameras![_selectedCameraIndex]);
    HapticFeedback.mediumImpact();
  }

  void _toggleFlash() {
    if (_controller == null) return;
    FlashMode newMode;
    if (_flashMode == FlashMode.off) {
      newMode = FlashMode.always;
    } else if (_flashMode == FlashMode.always) {
      newMode = FlashMode.auto;
    } else {
      newMode = FlashMode.off;
    }
    
    setState(() => _flashMode = newMode);
    _controller!.setFlashMode(newMode);
    HapticFeedback.lightImpact();
  }

  Timer? _recordingTimer;

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isCameraInitialized || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      HapticFeedback.heavyImpact();
      setState(() {
        _isRecording = true;
        _recordingProgress = 0.0;
      });

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final progress = (timer.tick * 100) / (_maxRecordingSeconds * 1000);
        if (progress >= 1.0) {
          _stopVideoRecording();
        } else {
          setState(() {
            _recordingProgress = progress;
          });
        }
      });
    } catch (e) {
      debugPrint('Video Recording Error: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final file = await _controller!.stopVideoRecording();
      HapticFeedback.selectionClick();
      setState(() {
        _isRecording = false;
        _recordingProgress = 0.0;
      });

      if (mounted) {
        _navigateToEditor(File(file.path));
      }
    } catch (e) {
      debugPrint('Stop Video Recording Error: $e');
      setState(() {
        _isRecording = false;
        _recordingProgress = 0.0;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _isRecording) return;

    try {
      final XFile file = await _controller!.takePicture();
      _playShutterSound();
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        _navigateToEditor(File(file.path));
      }
    } catch (e) {
      debugPrint('Capture Error: $e');
    }
  }

  Future<void> _playShutterSound() async {
    try {
      await _audioPlayer.setAsset(AppAssets.shutter);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing shutter sound: $e');
    }
  }

  void _navigateToEditor(File file) {
    Widget editor;
    switch (_currentMode) {
      case CreationMode.post:
        editor = PostEditorPage(files: [file]);
        break;
      case CreationMode.story:
        editor = StoryEditorPage(file: file);
        break;
      case CreationMode.reel:
        editor = ReelEditorPage(file: file);
        break;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => editor),
    );
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
                  : CreateType.story
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Positioned.fill(
            child: _isCameraInitialized && _controller != null
                ? Center(
                    child: CameraPreview(_controller!),
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: _cameras == null 
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.camera_off, color: Colors.white24, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _cameras!.isEmpty 
                                      ? (_permissionsDenied 
                                          ? 'Camera/Mic Permission Denied' 
                                          : 'No cameras found')
                                      : 'Initializing...',
                                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                                ),
                                if (_cameras!.isEmpty) ...[
                                  const SizedBox(height: 24),
                                  CupertinoButton(
                                    color: Colors.white10,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    borderRadius: BorderRadius.circular(20),
                                    onPressed: () {
                                      if (_isPermanentlyDenied) {
                                        openAppSettings();
                                      } else {
                                        _initCamera();
                                      }
                                    },
                                    child: Text(
                                      _isPermanentlyDenied ? 'Open Settings' : 'Retry',
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
          ),

          // 2. Top Controls
          Positioned(
            top: safeAreaTop + 8,
            left: 12, right: 12,
            child: Row(
              children: [
                _CameraIconButton(
                  iconPath: AppAssets.close,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _CameraIconButton(
                  icon: _flashMode == FlashMode.always 
                      ? LucideIcons.zap 
                      : _flashMode == FlashMode.auto 
                          ? LucideIcons.zap_off 
                          : LucideIcons.zap,
                  color: _flashMode == FlashMode.always ? Colors.yellow : Colors.white,
                  onTap: _toggleFlash,
                ),
                const SizedBox(width: 12),
                _CameraIconButton(icon: LucideIcons.settings, onTap: () {}),
              ],
            ),
          ),

          // 3. Right Tools
          Positioned(
            right: 12,
            top: 0, bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RightTool(
                    iconPath: AppAssets.flip, 
                    label: 'Flip',
                    onTap: _toggleCamera,
                  ),
                  _RightTool(icon: LucideIcons.timer, label: 'Timer', onTap: () {}),
                  _RightTool(icon: LucideIcons.sparkles, label: 'Effects', onTap: () {}),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 220 + safeAreaBottom,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Capture Button Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery Preview
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _openGallery,
                          child: Container(
                            width: 32, height: 32, // Match latest_thumbnails_container size
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.black,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _latestAsset != null
                                  ? AssetEntityImage(
                                      _latestAsset!,
                                      isOriginal: false,
                                      thumbnailSize: const ThumbnailSize.square(80),
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(LucideIcons.image, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        // Capture Button
                        _CaptureButton(
                          onTap: _takePicture,
                          onLongPressStart: () {
                            if (_currentMode != CreationMode.post) {
                              _startVideoRecording();
                            }
                          },
                          onLongPressEnd: () {
                            if (_isRecording) {
                              _stopVideoRecording();
                            }
                          },
                          isRecording: _isRecording,
                          progress: _recordingProgress,
                        ),
                        // Placeholder for symmetry
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Mode Selector
                  SizedBox(
                    height: 44,
                    child: PageView.builder(
                      controller: _modeController,
                      onPageChanged: _onModeChanged,
                      itemCount: CreationMode.values.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final mode = CreationMode.values[index];
                        final isSelected = _currentMode == mode;
                        return Center(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _modeController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            ),
                            child: Text(
                              mode.name.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12 + safeAreaBottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  final String? iconPath;
  final IconData? icon;
  final VoidCallback onTap;
  final Color color;
  const _CameraIconButton({this.iconPath, this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
        child: iconPath != null 
          ? Center(
              child: SvgPicture.asset(
                iconPath!, 
                width: 24, height: 24, 
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            )
          : Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _RightTool extends StatelessWidget {
  final String? iconPath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  const _RightTool({this.iconPath, this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.only(bottom: 20),
      onPressed: onTap,
      child: Column(
        children: [
          iconPath != null 
            ? SvgPicture.asset(
                iconPath!, 
                width: 24, height: 24, 
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              )
            : Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label, 
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final bool isRecording;
  final double progress;

  const _CaptureButton({
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.isRecording,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer progress ring
          SizedBox(
            width: 112, height: 112,
            child: CustomPaint(
              painter: _ProgressPainter(progress: progress, isRecording: isRecording),
            ),
          ),
          // Main Button (Resting at 0.66 scale of 112 = 74)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 112 * 0.9 : 112 * 0.66,
            height: isRecording ? 112 * 0.9 : 112 * 0.66,
            padding: EdgeInsets.all(isRecording ? 12 : 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white, 
                width: 4.0, // Match app:outer_circle_stroke_width="4.0dp"
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isRecording ? const Color(0xFFED4956) : Colors.white, // Instagram Red (approx)
                borderRadius: BorderRadius.circular(isRecording ? 12 : 112),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final bool isRecording;

  _ProgressPainter({required this.progress, required this.isRecording});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRecording) return;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // Start at top
      6.28318 * progress, // Sweep
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.isRecording != isRecording;
}
