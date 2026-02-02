import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../widgets/failure_animation.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final success =
        await authService.forgotPassword(_emailController.text.trim());

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        _showSuccessDialog();
      } else {
        String errorMessage =
            authService.error ?? 'Gagal mengirim email reset password';

        // Translate common errors
        if (errorMessage.contains("can't find a user") ||
            errorMessage.contains("tidak ditemukan")) {
          errorMessage = "Email tidak terdaftar dalam sistem kami.";
        } else if (errorMessage.contains("wait")) {
          errorMessage =
              "Terlalu banyak percobaan. Mohon tunggu beberapa saat.";
        }

        if (mounted) {
          FailureAnimation.show(
            context: context,
            title: 'Gagal Kirim Email',
            message: errorMessage,
          );
        }
      }
    }
  }

  Future<void> _openEmailApp() async {
    // Try to open Gmail specifically on Android, or default mail app
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: '',
    );

    // Specific intent for Android Gmail could be handled via android_intent_plus if installed,
    // but url_launcher 'mailto:' is the cross-platform standard.
    // We can try to just launch 'mailto:' which opens the chooser.

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi email')),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 60),
            SizedBox(height: 16),
            Text('Check Your Email', textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          'Kami telah mengirimkan link reset password ke email anda. Silahkan cek inbox atau spam folder.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to login
            },
            child: const Text('Kembali ke Login'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _openEmailApp();
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Buka Email App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon/Illustration
              const Icon(
                Icons.lock_reset,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),

              // Instructions
              Text(
                'Lupa Password?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Masukkan email yang terdaftar akun anda untuk mendapatkan link reset password.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Masukkan email anda',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mohon masukkan email';
                  }
                  if (!value.contains('@')) {
                    return 'Masukkan format email yang benar';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.primary,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Kirim Link Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
