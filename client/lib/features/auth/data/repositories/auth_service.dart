// lib/features/auth/data/repositories/auth_service.dart

import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';

class AuthService {
  final DioClient _dioClient = DioClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── REGISTER ──────────────────────────────────────────
  Future<AuthResponseModel> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        AppConstants.registerEndpoint,
        data: {
          'full_name': fullName,
          'email': email,
          'username': username,
          'password': password,
        },
      );

      // Parse response data
      final authResponse = AuthResponseModel.fromJson(response.data['data']);

      // Save tokens securely
      await _saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      // Save user data
      await _saveUser(authResponse.user);

      return authResponse;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // ─── LOGIN ─────────────────────────────────────────────
  Future<AuthResponseModel> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        AppConstants.loginEndpoint,
        data: {'identifier': identifier, 'password': password},
      );

      final authResponse = AuthResponseModel.fromJson(response.data['data']);

      // Save tokens securely
      await _saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      // Save user data
      await _saveUser(authResponse.user);

      return authResponse;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // ─── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    try {
      // Call backend logout
      await _dioClient.post(AppConstants.logoutEndpoint);
    } catch (e) {
      // Even if API call fails, clear local storage
      developer.log('Logout API error (still clearing local data): $e');
    } finally {
      // Always clear local storage
      await _clearStorage();
    }
  }

  // ─── GET CURRENT USER ──────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _dioClient.get(AppConstants.profileEndpoint);
      return UserModel.fromJson(response.data['data']['user']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return null; // Token expired
      }
      throw _handleDioError(e);
    }
  }

  // ─── CHECK USERNAME AVAILABILITY ───────────────────────
  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await _dioClient.get('/auth/check-username/$username');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── CHECK EMAIL AVAILABILITY ──────────────────────────
  Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final response = await _dioClient.get('/auth/check-email/$email');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ─── CHECK IF LOGGED IN ────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ─── GET STORED TOKEN ──────────────────────────────────
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  // ─── GET STORED USER ───────────────────────────────────
  Future<UserModel?> getStoredUser() async {
    try {
      final userJson = await _storage.read(key: AppConstants.userKey);
      if (userJson == null) return null;
      // Parse JSON string back to map
      // We'll store user as JSON string
      return null; // Simplified for now
    } catch (e) {
      return null;
    }
  }

  // ─── PRIVATE HELPERS ───────────────────────────────────

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _clearStorage();
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<void> _saveUser(UserModel user) async {
    // Save basic user info as key-value pairs
    await _storage.write(key: '${AppConstants.userKey}_id', value: user.id);
    await _storage.write(
      key: '${AppConstants.userKey}_username',
      value: user.username,
    );
    await _storage.write(
      key: '${AppConstants.userKey}_email',
      value: user.email,
    );
  }

  Future<void> _clearStorage() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
    await _storage.delete(key: '${AppConstants.userKey}_id');
    await _storage.delete(key: '${AppConstants.userKey}_username');
    await _storage.delete(key: '${AppConstants.userKey}_email');
  }

  // ─── HANDLE DIO ERRORS ─────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dioClient.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      // Server responded with error
      final message = e.response?.data?['message'] ?? 'Something went wrong';
      final errors = e.response?.data?['errors'];

      if (errors != null && errors is List) {
        // Validation errors
        final errorMessages = errors
            .map((err) => err['message'] as String)
            .join('\n');
        return Exception(errorMessages);
      }

      return Exception(message);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your internet.');
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception(
        'Cannot connect to server. Make sure backend is running.',
      );
    }
    return Exception('Network error: ${e.message}');
  }
}

// ─── CHANGE PASSWORD ─────────────────────────────────────
