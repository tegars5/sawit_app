import 'dart:io';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  String? get token => _apiClient.token;

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

      print('🔐 LOGIN: Attempting login for $email');
      final AuthResponse response = await _apiClient.login(email, password);
      print('✅ LOGIN: Success - Token received');

      // Save token and user
      await StorageService.saveToken(response.token);
      await StorageService.saveUser(response.user);

      // Update state
      _apiClient.setToken(response.token);
      _currentUser = response.user;

      _isLoading = false;
      notifyListeners();
      _isLoading = false;
      notifyListeners();

      // Sync FCM Token
      NotificationService.syncToken();

      return true;
    } catch (e) {
      print('❌ LOGIN ERROR: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final AuthResponse response = await _apiClient.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

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

  /// Update current user and save to storage
  void updateUser(User user) {
    _currentUser = user;
    StorageService.saveUser(user);
    notifyListeners();
  }

  Future<bool> updateProfilePhoto(File? imageFile) async {
    if (imageFile == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final photoUrl = await _apiClient.updateProfilePhoto(imageFile);

      if (_currentUser != null) {
        // Create new user object with updated photo
        _currentUser = User(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          role: _currentUser!.role,
          phone: _currentUser!.phone,
          address: _currentUser!.address,
          profilePicture: photoUrl,
          fcmToken: _currentUser!.fcmToken,
        );

        await StorageService.saveUser(_currentUser!);
      }

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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
