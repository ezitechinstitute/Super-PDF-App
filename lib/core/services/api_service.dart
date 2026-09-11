import 'package:dio/dio.dart';

import 'auth_storage.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  /*
  |--------------------------------------------------------------------------
  | API Configuration
  |--------------------------------------------------------------------------
  */

  static const String baseUrl = 'https://pdfapi.ezitech.org/api';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  late final Dio dio = _createDio();

  Dio _createDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: const {'Accept': 'application/json'},
        validateStatus: (status) {
          return status != null && status >= 200 && status < 300;
        },
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;

          // Public authentication endpoints do not need Bearer token.
          final isPublicRoute =
              path == '/register' ||
              path == '/verify-otp' ||
              path == '/login' ||
              path == '/forgot-password' ||
              path == '/reset-password';

          if (!isPublicRoute) {
            final token = await AuthStorage.getToken();

            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          // If a protected API returns 401, remove the local token.
          if (error.response?.statusCode == 401) {
            await AuthStorage.clearToken();
          }

          handler.next(error);
        },
      ),
    );

    return client;
  }

  // ==========================================================================
  // AUTHENTICATION
  // ==========================================================================

  /// 1. Register
  Future<Response<dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    return dio.post(
      '/register',
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
  }

  /// 2. Verify registration OTP
  Future<Response<dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await dio.post(
      '/verify-otp',
      data: {'email': email, 'otp': otp},
    );

    final token = response.data['token'];

    if (token is String && token.isNotEmpty) {
      await AuthStorage.saveToken(token);
    }

    return response;
  }

  /// 3. Login
  Future<Response<dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await dio.post(
      '/login',
      data: {'email': email, 'password': password},
    );

    final token = response.data['token'];

    if (token is String && token.isNotEmpty) {
      await AuthStorage.saveToken(token);
    }

    return response;
  }

  /// 4. Logout
  Future<Response<dynamic>> logout() async {
    try {
      return await dio.post('/logout');
    } finally {
      await AuthStorage.clearToken();
    }
  }

  /// 5. Get current authenticated user
  Future<Response<dynamic>> getCurrentUser() async {
    return dio.get('/user');
  }

  /// 6. Forgot password
  Future<Response<dynamic>> forgotPassword({required String email}) async {
    return dio.post('/forgot-password', data: {'email': email});
  }

  /// 7. Reset password
  Future<Response<dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return dio.post(
      '/reset-password',
      data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  // ==========================================================================
  // PROFILE
  // ==========================================================================

  /// 8. Get profile
  Future<Response<dynamic>> getProfile() async {
    return dio.get('/profile');
  }

  /// 9. Update profile
  Future<Response<dynamic>> updateProfile({String? name, String? phone}) async {
    final Map<String, dynamic> data = {};

    if (name != null) {
      data['name'] = name;
    }

    if (phone != null) {
      data['phone'] = phone;
    }

    return dio.put('/profile', data: data);
  }

  /// 10. Upload profile avatar
  Future<Response<dynamic>> uploadAvatar({required String filePath}) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;

    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    return dio.post('/profile/avatar', data: formData);
  }

  /// 11. Delete profile avatar
  Future<Response<dynamic>> deleteAvatar() async {
    return dio.delete('/profile/avatar');
  }

  // ==========================================================================
  // HISTORY
  // ==========================================================================

  /// 12. Get history
  Future<Response<dynamic>> getHistory({int page = 1}) async {
    return dio.get('/history', queryParameters: {'page': page});
  }

  /// 13. Create history record
  Future<Response<dynamic>> createHistory({
    required String toolName,
    required String fileName,
    String? outputFileName,
    String? status,
    int? fileSize,
    String? notes,
  }) async {
    final Map<String, dynamic> data = {
      'tool_name': toolName,
      'file_name': fileName,
    };

    if (outputFileName != null) {
      data['output_file_name'] = outputFileName;
    }

    if (status != null) {
      data['status'] = status;
    }

    if (fileSize != null) {
      data['file_size'] = fileSize;
    }

    if (notes != null) {
      data['notes'] = notes;
    }

    return dio.post('/history', data: data);
  }

  /// 14. Delete one history record
  Future<Response<dynamic>> deleteHistory({required int historyId}) async {
    return dio.delete('/history/$historyId');
  }

  /// 15. Delete all history
  Future<Response<dynamic>> deleteAllHistory() async {
    return dio.delete('/history');
  }

  /// 16. Get recent files
  Future<Response<dynamic>> getRecentFiles() async {
    return dio.get('/recent-files');
  }

  // ==========================================================================
  // AI
  // ==========================================================================

  /// 17. Get AI usage
  Future<Response<dynamic>> getAiUsage({int page = 1}) async {
    return dio.get('/ai/usage', queryParameters: {'page': page});
  }

  /// 18. Record AI usage
  Future<Response<dynamic>> createAiUsage({
    required String feature,
    String? fileName,
    int? tokensUsed,
    double? cost,
    String? status,
    String? notes,
  }) async {
    final Map<String, dynamic> data = {'feature': feature};

    if (fileName != null) {
      data['file_name'] = fileName;
    }

    if (tokensUsed != null) {
      data['tokens_used'] = tokensUsed;
    }

    if (cost != null) {
      data['cost'] = cost;
    }

    if (status != null) {
      data['status'] = status;
    }

    if (notes != null) {
      data['notes'] = notes;
    }

    return dio.post('/ai/usage', data: data);
  }

  /// 19. AI summarize
  Future<Response<dynamic>> summarize({
    required String fileName,
    required String text,
  }) async {
    return dio.post(
      '/ai/summarize',
      data: {'file_name': fileName, 'text': text},
    );
  }
}
