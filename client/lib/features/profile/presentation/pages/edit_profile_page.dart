import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String? _selectedGender;
  bool _isPrivate = false;
  XFile? _selectedXFile;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _websiteController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeFromUser(dynamic user) {
    if (_initialized || user == null) return;
    _initialized = true;

    _nameController.text = user.fullName ?? '';
    _usernameController.text = user.username ?? '';
    _bioController.text = user.bio ?? '';
    _websiteController.text = user.website ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phoneNumber ?? '';
    _selectedGender = user.gender;
    _isPrivate = user.isPrivate;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() => _selectedXFile = picked);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Error: $e');
      }
    }
  }

  void _showImagePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Change Profile Photo', style: TextStyle(fontFamily: 'SF-Pro')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'SF-Pro')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Take Photo', style: TextStyle(fontFamily: 'SF-Pro')),
          ),
          if (_selectedXFile != null || (ref.read(currentUserProvider)?.profilePicUrl != null))
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _selectedXFile = null);
              },
              child: const Text('Remove Current Photo', style: TextStyle(fontFamily: 'SF-Pro')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'SF-Pro')),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final notifier = ref.read(profileProvider(currentUser.username).notifier);

    if (_selectedXFile != null) {
      await notifier.updateProfilePicture(_selectedXFile!);
    }

    final success = await notifier.updateProfile(
      fullName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      website: _websiteController.text.trim(),
      gender: _selectedGender,
      isPrivate: _isPrivate,
    );

    if (success && mounted) {
      AppSnackbar.success(context, 'Profile updated!');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    _initializeFromUser(currentUser);
    final profileState = ref.watch(profileProvider(currentUser.username));
    final isSaving = profileState.isSaving;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[900]! : Colors.grey[300]!, width: 0.5)),
        leading: BouncyTap(
          onTap: () => context.pop(),
          child: Container(
            alignment: Alignment.centerLeft,
            child: Text(
              'Cancel', 
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black, 
                fontSize: 17, 
                fontFamily: 'SF-Pro'
              )
            ),
          ),
        ),
        middle: Text(
          'Edit Profile', 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 17, 
            fontFamily: 'SF-Pro',
            color: isDark ? Colors.white : Colors.black,
          )
        ),
        trailing: BouncyTap(
          onTap: isSaving ? null : _saveProfile,
          child: Container(
            alignment: Alignment.centerRight,
            child: isSaving 
              ? const CupertinoActivityIndicator(radius: 10)
              : const Text(
                  'Done', 
                  style: TextStyle(
                    color: Color(0xFF0095F6), 
                    fontWeight: FontWeight.w600, 
                    fontSize: 17, 
                    fontFamily: 'SF-Pro'
                  )
                ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAvatarSection(currentUser),
              const SizedBox(height: 10),
              
              CupertinoFormSection.insetGrouped(
                backgroundColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildFormRow('Name', _nameController, 'Name'),
                  _buildFormRow('Username', _usernameController, 'Username'),
                  _buildFormRow('Website', _websiteController, 'Website'),
                  _buildFormRow('Bio', _bioController, 'Bio', maxLines: 3),
                ],
              ),

              CupertinoFormSection.insetGrouped(
                backgroundColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  CupertinoFormRow(
                    child: BouncyTap(
                      onTap: () {},
                      child: const Row(
                        children: [
                          Text(
                            'Switch to Professional Account', 
                            style: TextStyle(
                              color: Color(0xFF0095F6), 
                              fontSize: 16, 
                              fontFamily: 'SF-Pro'
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(left: 32, top: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Personal Information Settings', 
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600], 
                      fontSize: 13, 
                      fontWeight: FontWeight.w600, 
                      fontFamily: 'SF-Pro'
                    )
                  ),
                ),
              ),

              CupertinoFormSection.insetGrouped(
                backgroundColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                children: [
                  _buildFormRow('Email', _emailController, 'Email', enabled: false),
                  _buildFormRow('Phone', _phoneController, 'Phone'),
                  _buildFormRow('Gender', TextEditingController(text: _formatGender(_selectedGender ?? '')), 'Gender', readOnly: true, onTap: _showGenderPicker),
                ],
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(dynamic user) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
          ),
          child: ClipOval(
            child: _selectedXFile != null
                ? Image.file(File(_selectedXFile!.path), fit: BoxFit.cover)
                : (user.profilePicUrl != null
                    ? CachedNetworkImage(imageUrl: user.profilePicUrl, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          user.username?[0].toUpperCase() ?? '?', 
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'SF-Pro')
                        )
                      )),
          ),
        ),
        const SizedBox(height: 12),
        BouncyTap(
          onTap: _showImagePicker,
          child: const Text(
            'Edit picture or avatar', 
            style: TextStyle(
              color: Color(0xFF0095F6), 
              fontWeight: FontWeight.w600, 
              fontSize: 14, 
              fontFamily: 'SF-Pro'
            )
          ),
        ),
      ],
    );
  }

  Widget _buildFormRow(String label, TextEditingController controller, String placeholder, {int maxLines = 1, bool enabled = true, bool readOnly = false, VoidCallback? onTap}) {
    return CupertinoFormRow(
      prefix: SizedBox(
        width: 90, 
        child: Text(
          label, 
          style: const TextStyle(fontSize: 16, fontFamily: 'SF-Pro')
        )
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
        enabled: enabled,
        readOnly: readOnly,
        onTap: onTap,
        decoration: null,
        padding: const EdgeInsets.symmetric(vertical: 12),
        style: const TextStyle(fontSize: 16, fontFamily: 'SF-Pro'),
        placeholderStyle: const TextStyle(color: CupertinoColors.placeholderText, fontFamily: 'SF-Pro'),
      ),
    );
  }

  void _showGenderPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Gender', style: TextStyle(fontFamily: 'SF-Pro')),
        actions: ['Male', 'Female', 'Custom', 'Prefer not to say'].map((g) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _selectedGender = g.toLowerCase().replaceAll(' ', '_'));
            Navigator.pop(ctx);
          },
          child: Text(g, style: const TextStyle(fontFamily: 'SF-Pro')),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'SF-Pro')),
        ),
      ),
    );
  }

  String _formatGender(String g) {
    if (g == 'prefer_not_to_say') return 'Prefer not to say';
    if (g.isEmpty) return 'Not specified';
    final parts = g.split('_');
    return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
  }
}
