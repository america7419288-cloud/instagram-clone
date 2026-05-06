// lib/features/profile/data/repositories/profile_service.dart

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/network/dio_client.dart';
import '../profile_model.dart';

class ProfileService {
  final DioClient _dioClient = DioClient();

  // ─── GET USER PROFILE ────────────────────────────────────
  Future<ProfileModel> getUserProfile(String username) async {
    try {
      final response = await _dioClient.get('/users/$username');
      return ProfileModel.fromJson(response.data['data']['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET USER POSTS (for grid) ───────────────────────────
  Future<Map<String, dynamic>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _dioClient.get(
        '/posts/user/$userId',
        queryParameters: {'page': page, 'limit': limit},
      );

      final posts = (response.data['data'] as List<dynamic>? ?? [])
          .map((p) => ProfilePostModel.fromJson(p as Map<String, dynamic>))
          .toList();

      return {'posts': posts, 'pagination': response.data['pagination']};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────
  Future<ProfileModel> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? website,
    String? gender,
    bool? isPrivate,
  }) async {
    try {
      // Build update map with only provided fields
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (username != null) data['username'] = username;
      if (bio != null) data['bio'] = bio;
      if (website != null) data['website'] = website;
      if (gender != null) data['gender'] = gender;
      if (isPrivate != null) data['is_private'] = isPrivate;

      final response = await _dioClient.put('/users/profile', data: data);

      return ProfileModel.fromJson(response.data['data']['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UPDATE PROFILE PICTURE ──────────────────────────────
  Future<String> updateProfilePicture(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await _dioClient.uploadFile(
        '/users/profile-picture',
        formData,
      );

      return response.data['data']['profile_pic_url'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REMOVE PROFILE PICTURE ──────────────────────────────
  Future<void> removeProfilePicture() async {
    try {
      await _dioClient.delete('/users/profile-picture');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message = e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}

