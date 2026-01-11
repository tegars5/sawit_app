import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/services/storage_service.dart';
import 'order_tracking_screen.dart';
import 'payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  Order? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // ✅ Get token and set it before loading
    final token = await StorageService.getToken();
    if (token != null) {
      _apiClient.setToken(token);
    }
    await _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final order = await _apiClient.getOrder(widget.orderId);

      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'on_delivery':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
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
        title: const Text('Order Detail'),
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
                      Text('Error loading order'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadOrderDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _order == null
                  ? const Center(child: Text('Order not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Order Header
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _order!.orderCode,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_order!.status)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _order!.status.toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: _getStatusColor(
                                                  _order!.status),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  DateFormat('dd MMMM yyyy, HH:mm')
                                      .format(_order!.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Delivery Address
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delivery Address',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _order!.destinationAddress,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Order Items
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_bag,
                                        color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order Items',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_order!.orderItems != null)
                                  ...(_order!.orderItems!.map((item) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.product?.name ??
                                                      'Product',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${item.quantity} x ${currencyFormat.format(item.price)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            currencyFormat
                                                .format(item.subtotal),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      currencyFormat
                                          .format(_order!.totalAmount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
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

                        // Payment Status
                        if (_order!.payment != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.payment,
                                          color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Payment',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Status'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _order!.payment!.isPaid
                                              ? AppColors.success
                                                  .withOpacity(0.1)
                                              : AppColors.warning
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _order!.payment!.status.toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: _order!.payment!.isPaid
                                                    ? AppColors.success
                                                    : AppColors.warning,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        if (_order!.status != 'cancelled' &&
                            _order!.status != 'completed') ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderTrackingScreen(
                                      orderId: _order!.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.location_on),
                              label: const Text('Track Order'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_order!.payment != null &&
                              !_order!.payment!.isPaid)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentScreen(
                                        orderId: _order!.id,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.payment),
                                label: const Text('Pay Now'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
    );
  }
}
