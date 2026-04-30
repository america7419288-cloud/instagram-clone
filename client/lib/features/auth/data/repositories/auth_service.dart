import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/models/user_model.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;
}

class AuthService {
  AuthService({DioClient? dioClient, FlutterSecureStorage? storage})
    : _dioClient = dioClient ?? DioClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final DioClient _dioClient;
  final FlutterSecureStorage _storage;

  Future<AuthResult> register({
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

      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      final user = UserModel.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
      final accessToken = tokens['accessToken']?.toString() ?? '';
      final refreshToken = tokens['refreshToken']?.toString() ?? '';

      await _storage.write(key: AppConstants.tokenKey, value: accessToken);
      await _storage.write(
        key: AppConstants.refreshTokenKey,
        value: refreshToken,
      );

      return AuthResult(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (error) {
      final responseData = error.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        throw AuthException(responseData['message'].toString());
      }
      throw const AuthException('Unable to create account. Please try again.');
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
