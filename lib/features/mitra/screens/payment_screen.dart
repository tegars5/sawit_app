import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/payment_response.dart';

class PaymentScreen extends StatefulWidget {
  final int orderId;

  const PaymentScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiClient _apiClient = ApiClient();
  PaymentResponse? _payment;
  bool _isLoading = false;
  String? _error;
  String _selectedMethod = 'QRIS';

  final List<Map<String, dynamic>> _paymentMethods = [
    {'code': 'QRIS', 'name': 'QRIS', 'icon': Icons.qr_code},
    {
      'code': 'BCAVA',
      'name': 'BCA Virtual Account',
      'icon': Icons.account_balance
    },
    {
      'code': 'BNIVA',
      'name': 'BNI Virtual Account',
      'icon': Icons.account_balance
    },
    {
      'code': 'BRIVA',
      'name': 'BRI Virtual Account',
      'icon': Icons.account_balance
    },
  ];

  Future<void> _processPayment() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final payment = await _apiClient.processPayment(
        widget.orderId,
        _selectedMethod,
      );

      setState(() {
        _payment = payment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: _payment != null
          ? _buildPaymentInstructions()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Method Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Payment Method',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ..._paymentMethods.map((method) {
                            return RadioListTile<String>(
                              value: method['code'],
                              groupValue: _selectedMethod,
                              onChanged: (value) {
                                setState(() => _selectedMethod = value!);
                              },
                              title: Text(method['name']),
                              secondary: Icon(method['icon'],
                                  color: AppColors.primary),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '• Payment will be processed through Tripay payment gateway\n'
                            '• You will receive payment instructions after confirmation\n'
                            '• Payment must be completed within 24 hours\n'
                            '• Order will be automatically cancelled if payment is not received',
                            style: TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Process Button
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment failed. Please try again.',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Proceed to Payment'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentInstructions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Created',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please complete your payment',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),

          // QR Code (if available)
          if (_payment!.qrCodeUrl != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Scan QR Code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 200,
                      height: 200,
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: Icon(Icons.qr_code, size: 100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'QR Code URL: ${_payment!.qrCodeUrl}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Payment Code
          if (_payment!.paymentCode != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Payment Code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _payment!.paymentCode!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment code copied!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Payment Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Reference', _payment!.reference ?? 'N/A'),
                  const Divider(height: 24),
                  _buildDetailRow('Method', _payment!.paymentMethod),
                  const Divider(height: 24),
                  _buildDetailRow('Status', _payment!.status.toUpperCase()),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Expires At',
                    DateFormat('dd MMM yyyy, HH:mm')
                        .format(_payment!.expiresAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Use the payment code or scan the QR code\n'
                    '2. Complete payment through your banking app\n'
                    '3. Payment will be verified automatically\n'
                    '4. You will receive confirmation once payment is successful',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Order'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
