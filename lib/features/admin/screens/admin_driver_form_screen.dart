import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import '../../../config/theme.dart';

class AdminDriverFormScreen extends StatefulWidget {
  final User? driver; // If null, we are in CREATE mode

  const AdminDriverFormScreen({super.key, this.driver});

  @override
  State<AdminDriverFormScreen> createState() => _AdminDriverFormScreenState();
}

class _AdminDriverFormScreenState extends State<AdminDriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _vehicleNumberController;

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  bool get _isEditing => widget.driver != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver?.name ?? '');
    _emailController = TextEditingController(text: widget.driver?.email ?? '');
    _phoneController = TextEditingController(text: widget.driver?.phone ?? '');
    _passwordController = TextEditingController();

    // Note: If User model doesn't have vehicle info yet, these will be empty.
    // We updated User model separately.

    _vehicleTypeController = TextEditingController(
        text: _isEditing ? (widget.driver?.vehicleType ?? '') : '');
    _vehicleNumberController = TextEditingController(
        text: _isEditing ? (widget.driver?.vehiclePlate ?? '') : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Initialize token before making API calls
      await _apiClient.initializeToken();

      final data = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'vehicle_type': _vehicleTypeController.text,
        'vehicle_number': _vehicleNumberController.text,
      };

      if (_isEditing) {
        if (_passwordController.text.isNotEmpty) {
          data['password'] = _passwordController.text;
        }
        await _apiClient.updateDriver(widget.driver!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver updated successfully')),
          );
        }
      } else {
        data['password'] = _passwordController.text;
        data['password_confirmation'] = _passwordController.text;
        await _apiClient.createDriver(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver created successfully')),
          );
        }
      }

      if (mounted) Navigator.pop(context, true); // Return true to refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Driver' : 'Add Driver'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) => v!.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleTypeController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type (e.g. Truck, Van)',
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Vehicle Type is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number (Plate)',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Vehicle Number is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Password (Leave blank to keep)'
                      : 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: (v) {
                  if (!_isEditing && (v == null || v.isEmpty)) {
                    return 'Password is required';
                  }
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : Text(_isEditing ? 'Update Driver' : 'Create Driver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
