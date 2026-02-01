import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../core/models/order.dart';
import 'swipe_complete_button.dart';

class DeliveryBottomSheet extends StatelessWidget {
  final Order order;
  final Future<void> Function() onComplete;
  final Function(String status)? onUpdateStatus;
  // ✅ REMOVED: onViewWaybill callback (waybill no longer accessible)
  final ScrollController? scrollController;

  const DeliveryBottomSheet({
    super.key,
    required this.order,
    required this.onComplete,
    this.onUpdateStatus,
    // ✅ REMOVED: onViewWaybill parameter
    this.scrollController,
  });

  String _getTotalWeight() {
    if (order.orderItems == null || order.orderItems!.isEmpty) {
      return '-';
    }
    double totalWeight = 0;
    for (var item in order.orderItems!) {
      totalWeight += item.quantity;
    }
    return '${totalWeight.toStringAsFixed(1)} Ton';
  }

  String _getProductName() {
    if (order.orderItems == null || order.orderItems!.isEmpty) {
      return 'Cangkang Sawit';
    }
    return order.orderItems!.first.product?.name ?? 'Cangkang Sawit';
  }

  String _getEstimatedTime() {
    if (order.estimatedMinutes == null) return '-';
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: order.estimatedMinutes!));
    return DateFormat('HH:mm').format(eta) + ' WIB';
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openMaps() async {
    // Open Google Maps
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${order.destinationLat},${order.destinationLng}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // Header: Status & ETA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusBadge(status: order.status),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Estimasi Tiba',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        Text(
                          _getEstimatedTime(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Customer Info
                _buildSectionTitle(context, 'PENERIMA'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (order.user?.name ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.user?.name ?? 'Customer',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (order.user?.phone != null)
                            Text(
                              order.user!.phone!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _CircleActionButton(
                      icon: Icons.chat_bubble,
                      color: Colors.green,
                      onTap: () {}, // TODO: Chat
                    ),
                    const SizedBox(width: 12),
                    _CircleActionButton(
                      icon: Icons.phone,
                      color: AppColors.primary,
                      onTap: () => _makePhoneCall(order.user?.phone),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Destination
                _buildSectionTitle(context, 'LOKASI TUJUAN'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place,
                          color: Colors.redAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          order.destinationAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openMaps,
                        icon: const Icon(Icons.map, color: Colors.blue),
                        tooltip: 'Buka Google Maps',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Cargo Info Grid
                _buildSectionTitle(context, 'DETAIL MUATAN'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.scale,
                        label: 'Berat Total',
                        value: _getTotalWeight(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.category,
                        label: 'Jenis Produk',
                        value: _getProductName(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),

          // Sticky Action Section
          if (order.status != 'completed' && order.status != 'cancelled')
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: _buildActionButton(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    // Primary Action Button content based on status
    if (order.status == 'assigned') {
      return ElevatedButton.icon(
        onPressed: () => onUpdateStatus?.call('picked_up'),
        icon: const Icon(Icons.check_box),
        label: const Text('Konfirmasi Penjemputan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      );
    } else if (order.status == 'picked_up') {
      return ElevatedButton.icon(
        onPressed: () => onUpdateStatus?.call('on_delivery'),
        icon: const Icon(Icons.local_shipping),
        label: const Text('Mulai Pengiriman'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      );
    } else if (order.status == 'on_delivery') {
      return SwipeCompleteButton(
        onComplete: onComplete,
        text: 'Geser untuk Selesai',
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color getStatusColor() {
      switch (status) {
        case 'assigned':
          return Colors.orange;
        case 'picked_up':
          return Colors.blue;
        case 'on_delivery':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    String getStatusText() {
      switch (status) {
        case 'assigned':
          return 'Menunggu Dijemput';
        case 'picked_up':
          return 'Barang Diangkut';
        case 'on_delivery':
          return 'Dalam Pengiriman';
        default:
          return 'Selesai';
      }
    }

    final color = getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        getStatusText(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
