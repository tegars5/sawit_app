import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../core/models/order.dart';
import '../providers/driver_order_provider.dart';
import 'driver_delivery_detail_screen.dart';

class DriverDeliveryListScreen extends StatefulWidget {
  const DriverDeliveryListScreen({super.key});

  @override
  State<DriverDeliveryListScreen> createState() =>
      _DriverDeliveryListScreenState();
}

class _DriverDeliveryListScreenState extends State<DriverDeliveryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final provider = Provider.of<DriverOrderProvider>(context, listen: false);
    await provider.loadOrders();
  }

  Future<void> _viewWaybill(Order order) async {
    print('🔍 DEBUG: _viewWaybill called');
    print('🔍 DEBUG: order.hasWaybill = ${order.hasWaybill}');
    print('🔍 DEBUG: order.waybillPdf = ${order.waybillPdf}');
    print(
        '🔍 DEBUG: order.deliveryOrder?.waybillPdf = ${order.deliveryOrder?.waybillPdf}');
    print('🔍 DEBUG: order.waybillUrl = ${order.waybillUrl}');

    if (order.waybillUrl == null) {
      print('❌ DEBUG: waybillUrl is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surat jalan belum tersedia')),
      );
      return;
    }

    print('✅ DEBUG: Attempting to open URL: ${order.waybillUrl}');
    final Uri url = Uri.parse(order.waybillUrl!);

    try {
      if (await canLaunchUrl(url)) {
        print('✅ DEBUG: canLaunchUrl returned true, launching...');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('❌ DEBUG: canLaunchUrl returned false');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka PDF')),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error launching URL: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _startDelivery(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDeliveryDetailScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'My Deliveries',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Notifications
            },
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Consumer<DriverOrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadOrders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final upcomingOrders = provider.orders
              .where((o) => o.status != 'completed' && o.status != 'delivered')
              .toList();
          final completedOrders = provider.orders
              .where((o) => o.status == 'completed' || o.status == 'delivered')
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Upcoming Tab
              _buildOrderList(upcomingOrders, isUpcoming: true),
              // Completed Tab
              _buildOrderList(completedOrders, isUpcoming: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, {required bool isUpcoming}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming
                  ? Icons.local_shipping_outlined
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming deliveries' : 'No completed deliveries',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _DeliveryCard(
            order: order,
            isUpcoming: isUpcoming,
            onViewWaybill: () => _viewWaybill(order),
            onStartDelivery: () => _startDelivery(order),
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Order order;
  final bool isUpcoming;
  final VoidCallback onViewWaybill;
  final VoidCallback onStartDelivery;

  const _DeliveryCard({
    required this.order,
    required this.isUpcoming,
    required this.onViewWaybill,
    required this.onStartDelivery,
  });

  String _getStatusLabel() {
    switch (order.status) {
      case 'assigned':
        return 'Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'on_delivery':
        return 'On Delivery';
      case 'delivered':
      case 'completed':
        return 'Completed';
      default:
        return order.status;
    }
  }

  Color _getStatusColor() {
    switch (order.status) {
      case 'assigned':
        return Colors.green;
      case 'picked_up':
        return Colors.orange;
      case 'on_delivery':
        return Colors.blue;
      case 'delivered':
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getFromLocation() {
    // Assuming warehouse or first pickup point
    return order.orderItems?.first.product?.name ?? 'PT PalmSource, Medan';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order ID + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order ID: ${order.orderCode}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // From Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.circle,
                    size: 12,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'From',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _getFromLocation(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // To Location
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 12,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        order.destinationAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(order.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isUpcoming) ...[
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  // View Surat Jalan Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: order.hasWaybill ? onViewWaybill : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View Surat Jalan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Start Delivery Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onStartDelivery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start Delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
