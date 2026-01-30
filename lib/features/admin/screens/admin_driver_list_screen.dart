import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import 'admin_driver_form_screen.dart';
import 'admin_driver_detail_screen.dart';

class AdminDriverListScreen extends StatefulWidget {
  const AdminDriverListScreen({super.key});

  @override
  State<AdminDriverListScreen> createState() => _AdminDriverListScreenState();
}

class _AdminDriverListScreenState extends State<AdminDriverListScreen> {
  final ApiClient _apiClient = ApiClient();
  List<User> _drivers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authService = context.read<AuthService>();
      final token = await StorageService.getToken();
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.getDrivers();

      setState(() {
        _drivers = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDriver(User driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text('Are you sure you want to delete ${driver.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ Initialize token before making API call
      await _apiClient.initializeToken();

      await _apiClient.deleteDriver(driver.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver deleted successfully')),
        );
        _loadDrivers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _navigateToForm({User? driver}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminDriverFormScreen(driver: driver),
      ),
    );

    if (result == true) {
      _loadDrivers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Management'),
        actions: [
          IconButton(
            onPressed: _loadDrivers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDrivers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _drivers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text('No drivers found'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDrivers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drivers.length,
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminDriverDetailScreen(driver: driver),
                                  ),
                                );
                                if (result == true) {
                                  _loadDrivers();
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  driver.name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(driver.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driver.email),
                                  if (driver.phone != null) Text(driver.phone!),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: driver.isAvailable
                                          ? AppColors.success
                                              .withValues(alpha: 0.1)
                                          : AppColors.textSecondary
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      driver.isAvailable ? 'Available' : 'Busy',
                                      style: TextStyle(
                                        color: driver.isAvailable
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _navigateToForm(driver: driver);
                                      } else if (value == 'delete') {
                                        _deleteDriver(driver);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 20,
                                                color: AppColors.error),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: AppColors.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
