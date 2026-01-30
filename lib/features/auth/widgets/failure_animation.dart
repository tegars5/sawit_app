import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../config/theme.dart';

class FailureAnimation extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const FailureAnimation({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<FailureAnimation> createState() => _FailureAnimationState();

  static Future<void> show({
    required BuildContext context,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => FailureAnimation(
        message: message,
        onDismiss: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _FailureAnimationState extends State<FailureAnimation> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Failure Animation (Lottie)
              Lottie.asset(
                'assets/animations/FAIL.json',
                width: 150,
                height: 150,
                repeat: false,
              ),
              const SizedBox(height: 16),

              const Text(
                'Login Gagal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
