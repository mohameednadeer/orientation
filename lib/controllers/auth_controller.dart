import 'package:flutter/foundation.dart';
import '../services/api/auth_api.dart';

class AuthController extends ChangeNotifier {
  final AuthApi _authApi;

  bool loading = false;
  String? errorMessage;

  AuthController({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      await _authApi.login(email, password);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      loading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Register with username, email, phone and password
  Future<bool> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      await _authApi.register(
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      loading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authApi.logout();
    notifyListeners();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authApi.isLoggedIn();
  }
}
