import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/order.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/order_service.dart';
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
        // 👇 Initialize stream for real-time UI updates
        _locationStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        );
      });
    }
  }

  Future<void> _handleComplete() async {
    try {
      // 1. Check Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak. Mohon aktifkan izin lokasi.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Mohon ubah di pengaturan.';
      }

      // 2. Get Current Location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Call API to complete delivery
      final orderService = OrderService();
      final result = await orderService.completeDelivery(
        orderId: _order.id,
        currentLat: position.latitude,
        currentLng: position.longitude,
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        // 4. Success - Stop tracking and navigate home
        _locationService.stopTracking();

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
            content: Text(
              result['message'] ?? 'Pengiriman telah berhasil diselesaikan.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Refresh home screen list by rebuilding it
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/driver/home',
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // 5. Failure (e.g. Geofencing)
        String message = result?['message'] ??
            orderService.error ??
            'Gagal menyelesaikan pesanan';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Konfirmasi Lokasi'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
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

  Future<void> _handleUpdateStatus(String newStatus) async {
    try {
      setState(() => _isTracking =
          true); // Reuse tracking var for loading state if needed, or add _isLoading

      await _apiClient.updateDriverOrderStatus(_order.id, newStatus);

      // Refresh order data (you might want to fetch fresh data from API)
      final updatedOrder = await _apiClient.getOrder(_order.id);

      if (mounted) {
        setState(() {
          _order = updatedOrder;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status berhasil diperbarui ke ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );

        // If starting delivery, ensure tracking is on
        if (newStatus == 'on_delivery') {
          _startTrackingIfNeeded();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        // setState(() => _isLoading = false);
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'picked_up':
        return 'Barang Diangkut';
      case 'on_delivery':
        return 'Dalam Pengiriman';
      default:
        return status;
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
        // Use panelBuilder to get ScrollController
        panelBuilder: (scrollController) => DeliveryBottomSheet(
          order: _order,
          onComplete: _handleComplete,
          onUpdateStatus: _handleUpdateStatus,
          onViewWaybill: _viewWaybill,
          scrollController: scrollController, // Pass the controller
        ),
      ),
    );
  }
}
