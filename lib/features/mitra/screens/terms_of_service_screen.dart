import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
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
              title: '1. Acceptance of Terms',
              content:
                  'By accessing and using the Cangkang Sawit mobile application, you accept and agree to be bound by these Terms of Service.',
            ),
            _buildSection(
              context,
              title: '2. User Accounts',
              content:
                  'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
            ),
            _buildSection(
              context,
              title: '3. Orders and Payments',
              content:
                  'All orders are subject to acceptance and availability. Prices are subject to change without notice. Payment must be made in full before delivery.',
            ),
            _buildSection(
              context,
              title: '4. Delivery',
              content:
                  'We will make reasonable efforts to deliver orders within the estimated timeframe. However, delivery times are not guaranteed.',
            ),
            _buildSection(
              context,
              title: '5. Returns and Refunds',
              content:
                  'Returns and refunds are handled on a case-by-case basis. Please contact customer support for assistance.',
            ),
            _buildSection(
              context,
              title: '6. Prohibited Activities',
              content:
                  'You may not use the app for any illegal or unauthorized purpose. You must not violate any laws in your jurisdiction.',
            ),
            _buildSection(
              context,
              title: '7. Limitation of Liability',
              content:
                  'Cangkang Sawit shall not be liable for any indirect, incidental, special, or consequential damages arising out of your use of the app.',
            ),
            _buildSection(
              context,
              title: '8. Changes to Terms',
              content:
                  'We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of modified terms.',
            ),
            _buildSection(
              context,
              title: '9. Contact Information',
              content:
                  'For questions about these Terms of Service, please contact us at support@cangkangsawit.com',
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
