import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../providers/ad_provider.dart';
import '../../data/repositories/ad_service.dart';
import 'ad_dashboard_page.dart';

class CreativeCreatePage extends ConsumerStatefulWidget {
  final String campaignId;
  const CreativeCreatePage({super.key, required this.campaignId});

  @override
  ConsumerState<CreativeCreatePage> createState() => _CreativeCreatePageState();
}

class _CreativeCreatePageState extends ConsumerState<CreativeCreatePage> {
  final _formKey = GlobalKey<FormState>();
  
  final _primaryController = TextEditingController();
  final _headlineController = TextEditingController();
  final _descController = TextEditingController();
  final _ctaUrlController = TextEditingController();
  final _storySwipeController = TextEditingController();

  String _type = 'image';
  String _ctaType = 'learn_more';
  
  File? _imageFile;
  File? _videoFile;
  File? _thumbnailFile;
  final List<File> _carouselFiles = [];

  bool _submitting = false;

  final List<Map<String, String>> _creativeTypes = const [
    {'value': 'image', 'label': 'Single Image (Feed)'},
    {'value': 'video', 'label': 'Reel / Feed Video'},
    {'value': 'carousel', 'label': 'Carousel Collection (Feed)'},
    {'value': 'story_image', 'label': 'Story Image (Vertical)'},
    {'value': 'story_video', 'label': 'Story Video (Vertical)'},
  ];

  final List<Map<String, String>> _ctas = const [
    {'value': 'learn_more', 'label': 'Learn More'},
    {'value': 'shop_now', 'label': 'Shop Now'},
    {'value': 'sign_up', 'label': 'Sign Up'},
    {'value': 'download', 'label': 'Download'},
    {'value': 'book_now', 'label': 'Book Now'},
    {'value': 'contact_us', 'label': 'Contact Us'},
    {'value': 'watch_more', 'label': 'Watch More'},
    {'value': 'apply_now', 'label': 'Apply Now'},
    {'value': 'get_offer', 'label': 'Get Offer'},
    {'value': 'install_now', 'label': 'Install Now'},
    {'value': 'order_now', 'label': 'Order Now'},
    {'value': 'subscribe', 'label': 'Subscribe'},
    {'value': 'no_button', 'label': 'No Button'},
  ];

  @override
  void dispose() {
    _primaryController.dispose();
    _headlineController.dispose();
    _descController.dispose();
    _ctaUrlController.dispose();
    _storySwipeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) {
      setState(() => _imageFile = File(img.path));
    }
  }

  Future<void> _pickVideo() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final vid = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (vid != null) {
      setState(() => _videoFile = File(vid.path));
    }
  }

  Future<void> _pickThumbnail() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      setState(() => _thumbnailFile = File(img.path));
    }
  }

  Future<void> _pickCarouselImages() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 85);
    if (list.isNotEmpty) {
      setState(() {
        _carouselFiles.addAll(list.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // File validation based on creative type
    if ((_type == 'image' || _type == 'story_image') && _imageFile == null) {
      _showError('Please pick an image file');
      return;
    }
    if ((_type == 'video' || _type == 'story_video') && _videoFile == null) {
      _showError('Please pick a video file');
      return;
    }
    if (_type == 'carousel' && _carouselFiles.isEmpty) {
      _showError('Please select at least 1 image for carousel');
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(adServiceProvider).createCreative(
        campaignId: widget.campaignId,
        type: _type,
        primaryText: _primaryController.text.trim(),
        headline: _headlineController.text.trim().isEmpty ? null : _headlineController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        ctaType: _ctaType,
        ctaUrl: _ctaUrlController.text.trim(),
        storySwipeUpText: _storySwipeController.text.trim().isEmpty ? 'See more' : _storySwipeController.text.trim(),
        storyOverlayColor: '#000000',
        image: _imageFile,
        video: _videoFile,
        thumbnail: _thumbnailFile,
        carouselImages: _carouselFiles,
      );

      if (mounted) {
        // Go back to the main dashboard and refresh
        ref.invalidate(advertiserOverviewProvider);
        ref.read(campaignsListProvider.notifier).loadCampaigns();
        
        Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (_) => const AdDashboardPage()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.white70 : Colors.black87;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: Text(
          'Upload Ad Creative',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Creative Placement Type *', isDark),
                _buildDropdown(
                  value: _type,
                  isDark: isDark,
                  items: _creativeTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _type = val;
                        // Clear selected files on type change
                        _imageFile = null;
                        _videoFile = null;
                        _thumbnailFile = null;
                        _carouselFiles.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // File Selectors based on Type
                _buildLabel('Media Asset *', isDark),
                _buildAssetSelector(isDark),
                const SizedBox(height: 24),

                // Form details
                _buildLabel('Primary Copy Text * (Max 125 chars)', isDark),
                _buildTextField(
                  controller: _primaryController,
                  placeholder: 'e.g. Get 20% off all orders this weekend only!',
                  isDark: isDark,
                  maxLines: 3,
                  maxLength: 125,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Primary text copy is required' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Headline (Optional - Max 40 chars)', isDark),
                _buildTextField(
                  controller: _headlineController,
                  placeholder: 'e.g. Summer Sale Active',
                  isDark: isDark,
                  maxLength: 40,
                ),
                const SizedBox(height: 16),

                _buildLabel('Description (Optional - Max 30 chars)', isDark),
                _buildTextField(
                  controller: _descController,
                  placeholder: 'e.g. Free shipping on all items',
                  isDark: isDark,
                  maxLength: 30,
                ),
                const SizedBox(height: 24),

                // Call to action selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('CTA Button Type', isDark),
                          _buildDropdown(
                            value: _ctaType,
                            isDark: isDark,
                            items: _ctas.map((cta) {
                              return DropdownMenuItem(value: cta['value'], child: Text(cta['label']!));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _ctaType = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('CTA Destination URL *', isDark),
                          _buildTextField(
                            controller: _ctaUrlController,
                            placeholder: 'https://mysite.com/shop',
                            isDark: isDark,
                            keyboardType: TextInputType.url,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Destination URL is required';
                              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                                return 'Must start with http/https';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Story specific fields
                if (_type.startsWith('story_')) ...[
                  _buildLabel('Story Swipe Up Text', isDark),
                  _buildTextField(
                    controller: _storySwipeController,
                    placeholder: 'See more',
                    isDark: isDark,
                    maxLength: 30,
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                CupertinoButton(
                  color: const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          'Upload & Launch Ad Campaign',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetSelector(bool isDark) {
    if (_type == 'image' || _type == 'story_image') {
      return _buildPickerCard(
        title: _imageFile != null ? 'Change Selected Image' : 'Choose Local Image File',
        icon: LucideIcons.image,
        isDark: isDark,
        imageFile: _imageFile,
        onTap: _pickImage,
      );
    } else if (_type == 'video' || _type == 'story_video') {
      return Column(
        children: [
          _buildPickerCard(
            title: _videoFile != null ? 'Change Selected Video' : 'Choose Local Video File',
            icon: LucideIcons.video,
            isDark: isDark,
            isPicked: _videoFile != null,
            onTap: _pickVideo,
          ),
          if (_videoFile != null) ...[
            const SizedBox(height: 12),
            _buildPickerCard(
              title: _thumbnailFile != null ? 'Change Video Thumbnail' : 'Choose Video Custom Cover (Optional)',
              icon: LucideIcons.image,
              isDark: isDark,
              imageFile: _thumbnailFile,
              onTap: _pickThumbnail,
            ),
          ],
        ],
      );
    } else if (_type == 'carousel') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPickerCard(
            title: 'Choose Multi Carousel Images',
            icon: LucideIcons.images,
            isDark: isDark,
            isPicked: _carouselFiles.isNotEmpty,
            onTap: _pickCarouselImages,
          ),
          if (_carouselFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _carouselFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_carouselFiles[idx], width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _carouselFiles.removeAt(idx);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPickerCard({
    required String title,
    required IconData icon,
    required bool isDark,
    File? imageFile,
    bool isPicked = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          image: imageFile != null ? DecorationImage(image: FileImage(imageFile), fit: BoxFit.cover) : null,
        ),
        child: imageFile == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: isPicked ? const Color(0xFF0095F6) : Colors.white54),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: isPicked ? const Color(0xFF0095F6) : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black38,
                ),
                child: const Center(
                  child: Icon(LucideIcons.refresh_cw, size: 28, color: Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0095F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
          icon: Icon(LucideIcons.chevron_down, color: isDark ? Colors.white54 : Colors.black45, size: 18),
          isExpanded: true,
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}
