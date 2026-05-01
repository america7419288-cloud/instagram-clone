// lib/features/profile/presentation/pages/edit_profile_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() =>
      _EditProfilePageState();
}

class _EditProfilePageState
    extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;

  String? _selectedGender;
  bool _isPrivate = false;
  File? _selectedImageFile;
  bool _initialized = false;
  String? _errorMessage;

  final List<String> _genderOptions = [
    'prefer_not_to_say',
    'male',
    'female',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _websiteController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // Initialize from current user data
  void _initializeFromUser(dynamic user) {
    if (_initialized || user == null) return;
    _initialized = true;

    _nameController.text = user.fullName ?? '';
    _usernameController.text = user.username ?? '';
    _bioController.text = user.bio ?? '';
    _websiteController.text = user.website ?? '';
    _selectedGender = user.gender;
    _isPrivate = user.isPrivate;
  }

  // Pick image from gallery or camera
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
        setState(() => _selectedImageFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final notifier = ref.read(
      profileProvider(currentUser.username).notifier,
    );

    // Upload new profile picture first if selected
    if (_selectedImageFile != null) {
      final picSuccess = await notifier.updateProfilePicture(
        _selectedImageFile!,
      );
      if (!picSuccess && mounted) {
        setState(() {
          _errorMessage =
              ref.read(profileProvider(currentUser.username)).errorMessage;
        });
        return;
      }
    }

    // Update profile details
    final success = await notifier.updateProfile(
      fullName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      website: _websiteController.text.trim(),
      gender: _selectedGender,
      isPrivate: _isPrivate,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully! ✅'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      context.pop();
    } else if (mounted) {
      setState(() {
        _errorMessage = ref
            .read(profileProvider(currentUser.username))
            .errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Initialize form with current user data
    _initializeFromUser(currentUser);

    final profileState = ref.watch(
      profileProvider(currentUser.username),
    );
    final isSaving = profileState.isSaving;

    return Scaffold(
      backgroundColor: AppColors.white,

      // ─── APP BAR ──────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.close,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveProfile,
            child: Text(
              'Done',
              style: TextStyle(
                color: isSaving
                    ? AppColors.border
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),

      // ─── BODY ─────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── PROFILE PICTURE ──────────────────────
              _buildProfilePicture(currentUser),

              const SizedBox(height: 24),

              // ─── ERROR MESSAGE ────────────────────────
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
                    ),
                  ),
                ),

              // ─── FORM FIELDS ──────────────────────────
              _buildFormField(
                label: 'Name',
                child: CustomTextField(
                  hint: 'Full name',
                  controller: _nameController,
                  validator: (v) => v?.isEmpty == true
                      ? 'Name is required'
                      : null,
                ),
              ),

              _buildFormField(
                label: 'Username',
                child: CustomTextField(
                  hint: 'Username',
                  controller: _usernameController,
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (v!.length < 3) return 'Min 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(v)) {
                      return 'Letters, numbers, . and _ only';
                    }
                    return null;
                  },
                ),
              ),

              _buildFormField(
                label: 'Bio',
                child: CustomTextField(
                  hint: 'Bio',
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 150,
                ),
              ),

              _buildFormField(
                label: 'Website',
                child: CustomTextField(
                  hint: 'Website',
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                ),
              ),

              // ─── GENDER ───────────────────────────────
              _buildFormField(
                label: 'Gender',
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  hint: const Text(
                    'Select gender',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: _genderOptions
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              _formatGender(g),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedGender = value),
                ),
              ),

              // ─── PRIVATE TOGGLE ───────────────────────
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                value: _isPrivate,
                onChanged: (value) =>
                    setState(() => _isPrivate = value),
                title: const Text(
                  'Private Account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Only approved followers can see your posts',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 1, color: AppColors.border),

              const SizedBox(height: 24),

              // ─── SAVE BUTTON ──────────────────────────
              CustomButton(
                text: 'Save Changes',
                isLoading: isSaving,
                onPressed: isSaving ? null : _saveProfile,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture(dynamic currentUser) {
    final profilePicUrl = _selectedImageFile != null
        ? null
        : currentUser.profilePicUrl as String?;

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.border,
          ),
          child: ClipOval(
            child: _selectedImageFile != null
                ? Image.file(
                    _selectedImageFile!,
                    fit: BoxFit.cover,
                  )
                : profilePicUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profilePicUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _defaultAvatar(
                          currentUser.username ?? '?',
                        ),
                      )
                    : _defaultAvatar(
                        currentUser.username ?? '?',
                      ),
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _showImagePicker,
          child: const Text(
            'Change profile photo',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar(String username) {
    return Container(
      color: AppColors.border,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  String _formatGender(String gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'custom':
        return 'Custom';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return gender;
    }
  }
}