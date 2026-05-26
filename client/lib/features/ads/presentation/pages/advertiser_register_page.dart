import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../providers/ad_provider.dart';
import 'ad_dashboard_page.dart';

class AdvertiserRegisterPage extends ConsumerStatefulWidget {
  const AdvertiserRegisterPage({super.key});

  @override
  ConsumerState<AdvertiserRegisterPage> createState() => _AdvertiserRegisterPageState();
}

class _AdvertiserRegisterPageState extends ConsumerState<AdvertiserRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  
  String _category = 'ecommerce';
  File? _logoFile;
  bool _submitting = false;

  final List<Map<String, String>> _categories = const [
    {'value': 'ecommerce', 'label': 'E-Commerce'},
    {'value': 'food', 'label': 'Food & Dining'},
    {'value': 'fashion', 'label': 'Fashion & Apparel'},
    {'value': 'tech', 'label': 'Technology & Software'},
    {'value': 'health', 'label': 'Health & Fitness'},
    {'value': 'beauty', 'label': 'Beauty & Personal Care'},
    {'value': 'travel', 'label': 'Travel & Tourism'},
    {'value': 'education', 'label': 'Education'},
    {'value': 'finance', 'label': 'Finance & Insurance'},
    {'value': 'entertainment', 'label': 'Entertainment'},
    {'value': 'gaming', 'label': 'Gaming'},
    {'value': 'real_estate', 'label': 'Real Estate'},
    {'value': 'automotive', 'label': 'Automotive'},
    {'value': 'sports', 'label': 'Sports & Outdoors'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _logoFile = File(image.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(advertiserProvider.notifier).register(
        businessName: _nameController.text.trim(),
        businessEmail: _emailController.text.trim(),
        businessCategory: _category,
        businessWebsite: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        logo: _logoFile,
      );

      if (mounted) {
        // Registration success, go to dashboard
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (_) => const AdDashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Registration Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.white70 : Colors.black87;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: Text(
          'Register Advertiser',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Logo Picker
                GestureDetector(
                  onTap: _pickLogo,
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                          backgroundImage: _logoFile != null ? FileImage(_logoFile!) : null,
                          child: _logoFile == null
                              ? Icon(LucideIcons.store, size: 40, color: isDark ? Colors.white54 : Colors.black45)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0095F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.camera, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Add Business Logo',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),

                // Business Name Input
                _buildLabel('Business Name *', isDark),
                _buildTextField(
                  controller: _nameController,
                  placeholder: 'e.g. Acme Corp',
                  isDark: isDark,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Business name is required' : null,
                ),
                const SizedBox(height: 20),

                // Business Email Input
                _buildLabel('Business Email *', isDark),
                _buildTextField(
                  controller: _emailController,
                  placeholder: 'e.g. contact@acme.com',
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Business email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Business Website Input
                _buildLabel('Website URL (Optional)', isDark),
                _buildTextField(
                  controller: _websiteController,
                  placeholder: 'e.g. https://acme.com',
                  isDark: isDark,
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                      return 'URL must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Category Picker
                _buildLabel('Business Category *', isDark),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      style: TextStyle(color: secondaryColor, fontSize: 15),
                      icon: Icon(LucideIcons.chevron_down, color: isDark ? Colors.white54 : Colors.black45, size: 20),
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['value'],
                          child: Text(cat['label']!),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                CupertinoButton(
                  color: const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(10),
                  pressedOpacity: 0.8,
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          'Register Advertiser',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black30),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0095F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
