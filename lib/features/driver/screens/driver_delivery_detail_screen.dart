import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/order.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/location_service.dart';
import '../widgets/delivery_map_view.dart';
import '../widgets/status_badge.dart';
import '../widgets/delivery_bottom_sheet.dart';

class DriverDeliveryDetailScreen extends StatefulWidget {
  final Order order;

  const DriverDeliveryDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<DriverDeliveryDetailScreen> createState() =>
      _DriverDeliveryDetailScreenState();
}

class _DriverDeliveryDetailScreenState
    extends State<DriverDeliveryDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  late LocationService _locationService;
  late Order _order;
  bool _isTracking = false;
  Stream<Position>? _locationStream;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeServices();

    // Auto-start tracking if status is on_delivery
    if (_order.status == 'on_delivery') {
      _startTrackingIfNeeded();
    }
  }

  Future<void> _initializeServices() async {
    await _apiClient.initializeToken();
    _locationService = LocationService(_apiClient);
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _startTrackingIfNeeded() async {
    if (_isTracking) return;

    final success = await _locationService.startTracking(_order.id);
    if (success && mounted) {
      setState(() {
        _isTracking = true;
      });
    }
  }

  Future<void> _handleComplete() async {
    try {
      // 1. Update status to backend
      await _apiClient.updateDriverOrderStatus(_order.id, 'delivered');

      // 2. Stop GPS tracking (save battery)
      _locationService.stopTracking();

      if (!mounted) return;

      // 3. Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Pengiriman Selesai!'),
            ],
          ),
          content: const Text(
            'Pengiriman telah berhasil diselesaikan. Terima kasih!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to list
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewWaybill() async {
    if (_order.waybillUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surat tugas belum tersedia')),
      );
      return;
    }

    final Uri url = Uri.parse(_order.waybillUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        parallaxEnabled: true,
        parallaxOffset: 0.5,
        minHeight: 300,
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        body: Stack(
          children: [
            // Map View
            DeliveryMapView(
              destinationLat: _order.destinationLat ?? 0,
              destinationLng: _order.destinationLng ?? 0,
              locationStream: _locationStream,
            ),

            // App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                ),
                title: const Text(
                  'Detail Pengiriman',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  // Waybill Button
                  if (_order.hasWaybill)
                    IconButton(
                      onPressed: _viewWaybill,
                      icon: const Icon(Icons.description, color: Colors.blue),
                      tooltip: 'Lihat Surat Tugas',
                    ),
                  // Bantuan Button
                ],
              ),
            ),

            // Status Badge
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              child: StatusBadge(status: _order.status),
            ),
          ],
        ),
        panel: DeliveryBottomSheet(
          order: _order,
          onComplete: _handleComplete,
          onViewWaybill: _viewWaybill,
        ),
      ),
    );
  }
}
