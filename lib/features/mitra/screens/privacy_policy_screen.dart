import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '1. Information We Collect',
              content:
                  'We collect information you provide directly to us, including your name, email address, phone number, and delivery address when you register for an account or place an order.',
            ),
            _buildSection(
              context,
              title: '2. How We Use Your Information',
              content:
                  'We use the information we collect to process your orders, communicate with you about your orders, provide customer support, and improve our services.',
            ),
            _buildSection(
              context,
              title: '3. Information Sharing',
              content:
                  'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as required to fulfill your orders (e.g., sharing delivery address with drivers).',
            ),
            _buildSection(
              context,
              title: '4. Data Security',
              content:
                  'We implement appropriate security measures to protect your personal information. However, no method of transmission over the internet is 100% secure.',
            ),
            _buildSection(
              context,
              title: '5. Your Rights',
              content:
                  'You have the right to access, update, or delete your personal information at any time through your account settings or by contacting us.',
            ),
            _buildSection(
              context,
              title: '6. Contact Us',
              content:
                  'If you have any questions about this Privacy Policy, please contact us at privacy@cangkangsawit.com',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
