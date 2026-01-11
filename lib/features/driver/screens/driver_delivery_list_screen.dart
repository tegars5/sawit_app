import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/models/order.dart';
import '../../../core/services/auth_service.dart';
import '../providers/driver_order_provider.dart';
import 'driver_delivery_detail_screen.dart';

class DriverDeliveryListScreen extends StatefulWidget {
  const DriverDeliveryListScreen({super.key});

  @override
  State<DriverDeliveryListScreen> createState() =>
      _DriverDeliveryListScreenState();
}

class _DriverDeliveryListScreenState extends State<DriverDeliveryListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final authService = context.read<AuthService>();
    final driverProvider = context.read<DriverOrderProvider>();

    if (authService.currentUser != null) {
      driverProvider.setToken(authService.currentUser!.id.toString());
      driverProvider.loadOrders();
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
    final driverProvider = context.watch<DriverOrderProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
      ),
      body: driverProvider.orders.isEmpty && driverProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : driverProvider.orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No deliveries assigned',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later for new assignments',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => driverProvider.loadOrders(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: driverProvider.orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = driverProvider.orders[index];
                      final deliveryOrder = order.deliveryOrder;

                      if (deliveryOrder == null) return const SizedBox.shrink();

                      return _DeliveryCard(
                        order: order,
                        currencyFormat: currencyFormat,
                        statusColor: _getStatusColor(deliveryOrder.status),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverDeliveryDetailScreen(
                                orderId: order.id,
                              ),
                            ),
                          );
                        },
                        onUpdateStatus: deliveryOrder.status != 'delivered'
                            ? () async {
                                String? newStatus;
                                if (deliveryOrder.status == 'assigned') {
                                  newStatus = 'picked_up';
                                } else if (deliveryOrder.status ==
                                    'picked_up') {
                                  newStatus = 'delivered';
                                }

                                if (newStatus != null) {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Update Status'),
                                      content: Text(
                                        'Update delivery status to ${newStatus!.replaceAll('_', ' ').toUpperCase()}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Update'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && context.mounted) {
                                    final success = await driverProvider
                                        .updateDeliveryStatus(
                                      deliveryOrder.id,
                                      newStatus,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Status updated successfully'
                                                : 'Failed to update status',
                                          ),
                                          backgroundColor: success
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Order order;
  final NumberFormat currencyFormat;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback? onUpdateStatus;

  const _DeliveryCard({
    required this.order,
    required this.currencyFormat,
    required this.statusColor,
    required this.onTap,
    this.onUpdateStatus,
  });

  String _getActionLabel(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Mark as Picked Up';
      case 'picked_up':
        return 'Mark as Delivered';
      default:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryOrder = order.deliveryOrder!;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      deliveryOrder.status.toUpperCase().replaceAll('_', ' '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.destinationAddress,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    currencyFormat.format(order.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              if (onUpdateStatus != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onUpdateStatus,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(_getActionLabel(deliveryOrder.status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
