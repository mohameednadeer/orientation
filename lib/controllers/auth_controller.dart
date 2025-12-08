import 'package:flutter/foundation.dart';
import '../services/api/auth_api.dart';

class AuthController extends ChangeNotifier {
  final AuthApi _authApi;

  bool loading = false;
  String? errorMessage;

  AuthController({AuthApi? authApi}) : _authApi = authApi ?? AuthApi();

  /// Sets the API base URL
  void setApiBaseUrl(String url) {
    _authApi.setBaseUrl(url);
  }

  /// Login with email and password
  /// TODO: Replace placeholder handling with real API logic
  Future<bool> login(String email, String password) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      // Placeholder: Will call real API when available
      await _authApi.login(email, password);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      loading = false;
      errorMessage = "Placeholder: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  /// Register with email and password
  /// TODO: Replace placeholder handling with real API logic
  Future<bool> register(String email, String password) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      // Placeholder: Will call real API when available
      await _authApi.register(email, password);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      loading = false;
      errorMessage = "Placeholder: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }
}
