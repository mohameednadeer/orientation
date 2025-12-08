import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dio_client.dart';
import '../../models/user_model.dart';

class AuthApi {
  final DioClient _dioClient = DioClient();

  AuthApi() {
    _dioClient.init();
  }

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      
      // Save token to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authResponse.token);
      await prefs.setString('user_id', authResponse.user.id);
      await prefs.setString('user_email', authResponse.user.email);
      await prefs.setString('user_name', authResponse.user.username);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Register with username, email, phone number and password
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      
      // Save token to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authResponse.token);
      await prefs.setString('user_id', authResponse.user.id);
      await prefs.setString('user_email', authResponse.user.email);
      await prefs.setString('user_name', authResponse.user.username);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout and clear stored data
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Get stored user info
  Future<Map<String, String?>> getStoredUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('auth_token'),
      'userId': prefs.getString('user_id'),
      'email': prefs.getString('user_email'),
      'username': prefs.getString('user_name'),
    };
  }

  /// Handle Dio errors and return user-friendly messages
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'];
        
        if (statusCode == 401) {
          return message ?? 'Invalid email or password.';
        } else if (statusCode == 409) {
          return message ?? 'User already exists.';
        } else if (statusCode == 400) {
          // Handle validation errors
          if (message is List) {
            return message.join('\n');
          }
          return message ?? 'Invalid input. Please check your data.';
        }
        return message ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
