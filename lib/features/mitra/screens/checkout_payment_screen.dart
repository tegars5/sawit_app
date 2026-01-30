import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/storage_service.dart';
import 'payment_success_screen.dart';

class CheckoutPaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;

  const CheckoutPaymentScreen({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  final ApiClient _apiClient = ApiClient();
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  String? _error;

  // Available payment methods (from Tripay)
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'code': 'BRIVA',
      'name': 'BRI Virtual Account',
      'icon': Icons.account_balance,
    },
    {
      'code': 'BCAVA',
      'name': 'BCA Virtual Account',
      'icon': Icons.account_balance,
    },
    {
      'code': 'MANDIRIVA',
      'name': 'Mandiri Virtual Account',
      'icon': Icons.account_balance,
    },
    {
      'code': 'QRIS',
      'name': 'QRIS',
      'icon': Icons.qr_code,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeToken();
  }

  Future<void> _initializeToken() async {
    final token = await StorageService.getToken();
    if (token != null) {
      _apiClient.setToken(token);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      _showFailureDialog(
        title: 'Metode Pembayaran',
        message: 'Silakan pilih metode pembayaran terlebih dahulu.',
      );
      return;
    }

    // Hitung total quantity
    int totalQty = widget.cartItems
        .fold(0, (sum, item) => sum + (item['quantity'] as int));

    // ❌ VALIDASI: Cek minimal 10 Ton
    if (totalQty < 10) {
      _showFailureDialog(
        title: 'Pemesanan Gagal',
        message:
            'Mohon maaf, minimum pemesanan adalah 10 Ton.\nTotal pesanan Anda saat ini: $totalQty Ton.',
      );
      return; // Stop proses
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Call backend to initiate payment
      final response = await _apiClient.initiateCheckoutPayment(
        destinationAddress: widget.destinationAddress,
        destinationLat: widget.destinationLat,
        destinationLng: widget.destinationLng,
        items: widget.cartItems,
        paymentMethod: _selectedPaymentMethod!,
      );

      final checkoutUrl = response['checkout_url'] as String;
      final orderId = response['order']['id'] as int;

      // Open Tripay payment page
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Navigate to success screen (user will return here after payment)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(orderId: orderId),
            ),
          );
        }
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        _showFailureDialog(
          title: 'Pembayaran Gagal',
          message:
              'Terjadi kesalahan saat memproses pembayaran:\n${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  void _showFailureDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎬 Lottie Animation
            Lottie.asset(
              'assets/animations/error.json',
              width: 150,
              height: 150,
              repeat: false,
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Order Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.cartItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['quantity']}x ${item['product_name']}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            currencyFormat.format(item['subtotal']),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        currencyFormat.format(widget.totalAmount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Methods
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Payment Method',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method['code'];
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedPaymentMethod = method['code']);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.05)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              method['icon'] as IconData,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                method['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Error Message
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Proceed to Payment'),
          ),
        ),
      ),
    );
  }
}
