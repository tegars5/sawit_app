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
    if (order.waybillUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surat jalan belum tersedia')),
      );
      return;
    }

    final Uri url = Uri.parse(order.waybillUrl!);
    print('🔍 DEBUG: Launching Waybill URL: $url');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback catch-all
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka PDF: $e')),
      );
    }
  }

  Future<void> _startDelivery(Order order) async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memulai pengiriman...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Get provider
      final provider = Provider.of<DriverOrderProvider>(context, listen: false);

      // Update status to on_delivery via API
      // This will also auto-start GPS tracking
      final success = await provider.updateOrderStatus(order.id, 'on_delivery');

      if (!success) {
        throw Exception('Gagal update status');
      }

      if (!mounted) return;

      // Navigate to detail screen with updated order
      final updatedOrder = provider.orders.firstWhere(
        (o) => o.id == order.id,
        orElse: () => order,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverDeliveryDetailScreen(order: updatedOrder),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai pengiriman: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Daftar Pengiriman',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Selesai'),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  TextButton(
                    onPressed: _loadOrders,
                    child: const Text('Coba Lagi'),
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
              _buildOrderList(upcomingOrders, isUpcoming: true),
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
                  : Icons.assignment_turned_in_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming
                  ? 'Tidak ada pengiriman aktif'
                  : 'Belum ada riwayat pengiriman',
              style: TextStyle(color: Colors.grey[600]),
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
          return _DeliveryCard(
            order: orders[index],
            isUpcoming: isUpcoming,
            onViewWaybill: () => _viewWaybill(orders[index]),
            onStartDelivery: () => _startDelivery(orders[index]),
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

  Color _getStatusColor() {
    switch (order.status) {
      case 'assigned':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'on_delivery':
        return Colors.green;
      case 'delivered':
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (order.status) {
      case 'assigned':
        return 'Ditugaskan';
      case 'picked_up':
        return 'Diangkut';
      case 'on_delivery':
        return 'Dikirim';
      case 'delivered':
      case 'completed':
        return 'Selesai';
      default:
        return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.orderCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Timeline Style Locations
                _buildTimelineRow(
                  icon: Icons.circle,
                  iconColor: Colors.green,
                  label: 'Dari',
                  value:
                      order.orderItems?.first.product?.name ?? 'Gudang Utama',
                  isLast: false,
                ),
                _buildTimelineRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'Ke',
                  value: order.destinationAddress,
                  isLast: true,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Date & Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(order.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (order.estimatedMinutes != null)
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            '~${order.estimatedMinutes} min',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onViewWaybill(),
                        icon: const Icon(Icons.description, size: 18),
                        label: const Text('Surat Jalan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: onStartDelivery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Kirim',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 16, color: iconColor),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isLast) const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
