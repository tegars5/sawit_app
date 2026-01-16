import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Ditugaskan';
      case 'picked_up':
        return 'Barang Diambil';
      case 'on_delivery':
        return 'Dalam Perjalanan';
      case 'arrived':
        return 'Tiba di Lokasi';
      case 'delivered':
        return 'Selesai';
      default:
        return status.toUpperCase().replaceAll('_', ' ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return AppColors.info;
      case 'picked_up':
      case 'on_delivery':
        return AppColors.primary;
      case 'arrived':
        return Colors.orange;
      case 'delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping,
              color: _getStatusColor(status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STATUS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _getStatusText(status),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
