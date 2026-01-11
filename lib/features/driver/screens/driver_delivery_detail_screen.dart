import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';

class DriverDeliveryDetailScreen extends StatefulWidget {
  final int orderId;

  const DriverDeliveryDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DriverDeliveryDetailScreen> createState() =>
      _DriverDeliveryDetailScreenState();
}

class _DriverDeliveryDetailScreenState
    extends State<DriverDeliveryDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  Order? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
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
      case 'assigned':
        return AppColors.info;
      case 'picked_up':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
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
        title: const Text('Delivery Detail'),
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
                      const Text('Error loading delivery'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadOrderDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _order == null
                  ? const Center(child: Text('Delivery not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Delivery Header
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
                                    if (_order!.deliveryOrder != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                                  _order!.deliveryOrder!.status)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _order!.deliveryOrder!.status
                                              .toUpperCase()
                                              .replaceAll('_', ' '),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: _getStatusColor(_order!
                                                    .deliveryOrder!.status),
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
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Maps integration coming soon!'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.map),
                                    label: const Text('Open in Maps'),
                                  ),
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

                        // Customer Info
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person,
                                        color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Customer Information',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_order!.user != null) ...[
                                  Text(
                                    _order!.user!.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _order!.user!.phone ?? '-',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Call feature coming soon!'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.phone),
                                      label: const Text('Call Customer'),
                                    ),
                                  ),
                                ] else
                                  const Text('No customer information'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
