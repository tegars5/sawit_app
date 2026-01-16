import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../core/models/order.dart';
import 'swipe_complete_button.dart';

class DeliveryBottomSheet extends StatelessWidget {
  final Order order;
  final Future<void> Function() onComplete;
  final VoidCallback? onViewWaybill;

  const DeliveryBottomSheet({
    super.key,
    required this.order,
    required this.onComplete,
    this.onViewWaybill,
  });

  String _getTotalWeight() {
    if (order.orderItems == null || order.orderItems!.isEmpty) {
      return '-';
    }

    double totalWeight = 0;
    for (var item in order.orderItems!) {
      // Assuming each item quantity represents tons
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
    if (order.estimatedMinutes == null) {
      return '-';
    }

    final now = DateTime.now();
    final eta = now.add(Duration(minutes: order.estimatedMinutes!));
    return DateFormat('HH:mm').format(eta) + ' WIB';
  }

  String _getRemainingTime() {
    if (order.estimatedMinutes == null) {
      return '-';
    }

    return '~${order.estimatedMinutes} Menit lagi';
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openChat() async {
    // TODO: Implement chat functionality
    // For now, just show a message
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Customer Info Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.user?.name ?? 'Customer',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mitra Terverifikasi',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.success,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    IconButton(
                      onPressed: _openChat,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _makePhoneCall(order.user?.phone),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Waybill Card (if available)
                if (order.hasWaybill)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Surat Tugas Tersedia',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              Text(
                                'Lihat sebelum mulai',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onViewWaybill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Lihat',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Info Cards Row
                Row(
                  children: [
                    // Muatan Card
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.inventory_2,
                        iconColor: AppColors.primary,
                        label: 'MUATAN',
                        value: _getTotalWeight(),
                        subtitle: _getProductName(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Estimasi Card
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.access_time,
                        iconColor: Colors.orange,
                        label: 'ESTIMASI',
                        value: _getEstimatedTime(),
                        subtitle: _getRemainingTime(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Lokasi Tujuan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lokasi Tujuan',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.destinationAddress,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Open in maps
                        },
                        icon: const Icon(Icons.navigation),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Swipe to Complete Button
                SwipeCompleteButton(
                  onComplete: onComplete,
                  text: 'Geser untuk Sampai',
                ),

                const SizedBox(height: 8),

                // Info text
                Text(
                  'Pastikan Anda berada di lokasi yang aman',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
