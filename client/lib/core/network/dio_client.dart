import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/server_config_provider.dart';

class DioClient {
  factory DioClient() => _instance;

  DioClient._internal() {
    _dio = Dio(_buildOptions(AppConstants.dynamicBaseUrl));
    _refreshDio = Dio(_buildOptions(AppConstants.dynamicBaseUrl));

    _authInterceptor = _AuthInterceptor(
      storage: _storage,
      refreshDio: _refreshDio,
      onRefreshStateChanged: _setRefreshing,
      isRefreshing: () => _isRefreshing,
    );

    _dio.interceptors.addAll([
      _authInterceptor,
      _loggerInterceptor(),
    ]);

    _refreshDio.interceptors.add(_loggerInterceptor());
  }

  static final DioClient _instance = DioClient._internal();

  late final Dio _dio;
  late final Dio _refreshDio;
  late final _AuthInterceptor _authInterceptor;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isRefreshing = false;

  void resetTokenCache() {
    _authInterceptor.resetCache();
  }

  BaseOptions _buildOptions(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  void _updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    _refreshDio.options.baseUrl = baseUrl;
  }

  void _setRefreshing(bool value) {
    _isRefreshing = value;
  }

  Interceptor _loggerInterceptor() {
    return PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
    );
  }

  Dio get dio => _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.put(path, data: data, options: options);
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.delete(path, data: data, options: options);
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    return _dio.patch(path, data: data, options: options);
  }

  Future<Response<dynamic>> uploadFile(
    String path,
    FormData formData, {
    Function(int, int)? onSendProgress,
  }) async {
    return _dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        headers: const {'Content-Type': 'multipart/form-data'},
      ),
    );
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({
    required FlutterSecureStorage storage,
    required Dio refreshDio,
    required void Function(bool value) onRefreshStateChanged,
    required bool Function() isRefreshing,
  }) : _storage = storage,
       _refreshDio = refreshDio,
       _onRefreshStateChanged = onRefreshStateChanged,
       _isRefreshing = isRefreshing;

  final FlutterSecureStorage _storage;
  final Dio _refreshDio;
  final void Function(bool value) _onRefreshStateChanged;
  final bool Function() _isRefreshing;
  String? _cachedToken;

  void resetCache() {
    _cachedToken = null;
  }

  static const _skipInterceptorKey = 'skipAuthInterceptor';
  static const _retryKey = 'authRetryAttempted';

  bool _shouldSkip(RequestOptions options) {
    final extra = options.extra[_skipInterceptorKey];
    if (extra == true) {
      return true;
    }

    const skipPaths = <String>[
      '/auth/login',
      '/auth/register',
      '/auth/verify-email',
      '/auth/resend-otp',
      '/auth/refresh-token',
      '/auth/check-username',
      '/auth/check-email',
      '/auth/forgot-password',
      '/auth/verify-reset-otp',
      '/auth/reset-password',
      '/auth/otp/',
    ];

    return skipPaths.any(options.path.contains);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // ── Swapping Base URL dynamically for Auth Service routes ──
    final path = options.path;
    final isAuthServiceRoute = (
      path.contains('/auth/register') ||
      path.contains('/auth/verify-email') ||
      path.contains('/auth/resend-otp') ||
      path.contains('/auth/login') ||
      path.contains('/auth/refresh-token') ||
      path.contains('/auth/logout') ||
      path.contains('/auth/logout-all') ||
      path.contains('/auth/sessions') ||
      path.contains('/auth/otp/') ||
      path.contains('/auth/forgot-password') ||
      path.contains('/auth/verify-reset-otp') ||
      path.contains('/auth/reset-password') ||
      path.contains('/auth/change-password')
    ) && !path.contains('/auth/me');

    if (isAuthServiceRoute) {
      final currentBaseUrl = options.baseUrl;
      if (currentBaseUrl.contains(':5000')) {
        options.baseUrl = currentBaseUrl.replaceAll(':5000', ':4000').replaceAll('/api/v1', '');
      } else if (currentBaseUrl.contains(':3000')) {
        options.baseUrl = currentBaseUrl.replaceAll(':3000', ':4000').replaceAll('/api/v1', '');
      } else {
        options.baseUrl = AppConstants.authBaseUrl;
      }
    }

    if (_shouldSkip(options)) {
      handler.next(options);
      return;
    }

    if (_cachedToken == null || _cachedToken!.isEmpty) {
      _cachedToken = await _storage.read(key: AppConstants.tokenKey);
    }

    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_cachedToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final requestOptions = err.requestOptions;

    if (statusCode != 401 || _shouldSkip(requestOptions)) {
      handler.next(err);
      return;
    }

    if (requestOptions.extra[_retryKey] == true || _isRefreshing()) {
      await _clearSession();
      handler.next(err);
      return;
    }

    _onRefreshStateChanged(true);

    try {
      final newAccessToken = await _refreshAccessToken();
      if (newAccessToken == null) {
        await _clearSession();
        handler.next(err);
        return;
      }

      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      requestOptions.extra[_retryKey] = true;

      final response = await _refreshDio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } catch (_) {
      await _clearSession();
      handler.next(err);
    } finally {
      _onRefreshStateChanged(false);
    }
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(
      key: AppConstants.refreshTokenKey,
    );

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: const {_skipInterceptorKey: true},
          headers: {'Authorization': null},
        ),
      );

      final data = response.data;
      Map<String, dynamic>? tokens;
      if (data is Map<String, dynamic>) {
        final responseData = data['data'];
        if (responseData is Map<String, dynamic>) {
          final tokenData = responseData['tokens'];
          if (tokenData is Map<String, dynamic>) {
            tokens = tokenData;
          }
        }
      }

      final accessToken = tokens?['accessToken']?.toString();
      final newRefreshToken = tokens?['refreshToken']?.toString();

      if (response.statusCode != 200 ||
          accessToken == null ||
          accessToken.isEmpty) {
        return null;
      }

      await _storage.write(key: AppConstants.tokenKey, value: accessToken);
      _cachedToken = accessToken;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write(
          key: AppConstants.refreshTokenKey,
          value: newRefreshToken,
        );
      }

      return accessToken;
    } on DioException {
      return null;
    }
  }

  Future<void> _clearSession() async {
    _cachedToken = null;
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
    await _storage.delete(key: '${AppConstants.userKey}_id');
    await _storage.delete(key: '${AppConstants.userKey}_username');
    await _storage.delete(key: '${AppConstants.userKey}_email');
  }
}

final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();
  final config = ref.watch(serverConfigProvider);
  client._updateBaseUrl(config.baseUrl);
  return client;
});

