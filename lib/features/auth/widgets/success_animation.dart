import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class SuccessAnimation extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;
  final Duration duration;

  const SuccessAnimation({
    super.key,
    required this.message,
    required this.onComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();

  static Future<void> show({
    required BuildContext context,
    required String message,
    required VoidCallback onComplete,
    Duration duration = const Duration(seconds: 2),
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => SuccessAnimation(
        message: message,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
        duration: duration,
      ),
    );
  }
}

class _SuccessAnimationState extends State<SuccessAnimation> {
  @override
  void initState() {
    super.initState();

    // Auto-dismiss after animation completes
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(32),
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
              // Success Icon with Animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 80,
                        color: AppColors.success,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Success Message
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Redirecting...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
