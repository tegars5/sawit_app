import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import '../services/storage_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    final token = StorageService.getToken();
    final user = StorageService.getUser();

    if (token != null && user != null) {
      _apiClient.setToken(token);
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final AuthResponse response = await _apiClient.login(email, password);

      // Save token and user
      await StorageService.saveToken(response.token);
      await StorageService.saveUser(response.user);

      // Update state
      _apiClient.setToken(response.token);
      _currentUser = response.user;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final AuthResponse response = await _apiClient.register(data);

      // Save token and user
      await StorageService.saveToken(response.token);
      await StorageService.saveUser(response.user);

      // Update state
      _apiClient.setToken(response.token);
      _currentUser = response.user;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (e) {
      // Ignore logout errors
    } finally {
      // Clear local data
      await StorageService.deleteToken();
      await StorageService.deleteUser();
      _apiClient.clearToken();
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _apiClient.getCurrentUser();
      _currentUser = user;
      await StorageService.saveUser(user);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
