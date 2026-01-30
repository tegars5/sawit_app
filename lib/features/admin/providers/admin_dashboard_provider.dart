import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/admin_dashboard_summary.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  AdminDashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  AdminDashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _apiClient.setToken(token);
  }

  Future<void> loadDashboardSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final summary = await _apiClient.getAdminDashboardSummary();
      _summary = summary;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
