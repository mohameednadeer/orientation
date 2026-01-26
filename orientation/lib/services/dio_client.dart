import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  // Production API URL - your deployed EC2 instance
  static const String productionUrl = 'http://15.185.100.83:3000';
  
  // Local development URLs (keep for testing)
  static const String localUrl = 'http://localhost:3000';
  static const String androidEmulatorUrl = 'http://10.0.2.2:3000';
  
  // Default to production
  String _baseUrl = productionUrl;
  late Dio dio;

  /// Set the base URL dynamically
  void setBaseUrl(String url) {
    _baseUrl = url;
    init(); // Reinitialize with new URL
  }

  void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging and token handling
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // For FormData (multipart), do not force JSON Content-Type; Dio sets multipart/form-data
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          
          // Add auth token to requests if available
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          // Log errors for debugging
          print('DioError: ${error.message}');
          if (error.response != null) {
            print('Response: ${error.response?.data}');
            print('Status: ${error.response?.statusCode}');
          }
          return handler.next(error);
        },
      ),
    );
  }
}
