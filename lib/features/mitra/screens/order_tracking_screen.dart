import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/tracking_response.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final ApiClient _apiClient = ApiClient();
  final Completer<GoogleMapController> _controller = Completer();

  TrackingResponse? _trackingData;
  Timer? _timer;
  bool _isLoading = true;

  // Google Maps State
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  final Map<MarkerId, Marker> _markers = {};

  // Gunakan API Key yang sudah Kakak buat
  final String googleMapsApiKey = "AIzaSyDQOtvxYHnviEl-e_aQjamwVH8bQZnwh8U";

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// Initialize token and start fetching tracking data
  Future<void> _initializeAndFetch() async {
    // 1. Load token dari SharedPreferences
    final hasToken = await _apiClient.initializeToken();

    if (!hasToken) {
      // Jika tidak ada token, redirect ke login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi Anda telah berakhir. Silakan login kembali.'),
            backgroundColor: Colors.red,
          ),
        );
        // Navigate to login - adjust route name sesuai dengan routing Anda
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // 2. Fetch data pertama kali
    await _fetchTrackingData();

    // 3. Setup polling dengan safety check
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        // Hanya fetch jika widget masih mounted
        if (mounted) {
          _fetchTrackingData();
        } else {
          // Jika sudah tidak mounted, cancel timer
          timer.cancel();
        }
      },
    );
  }

  Future<void> _fetchTrackingData() async {
    try {
      final data = await _apiClient.getOrderTracking(widget.orderId);

      if (mounted) {
        setState(() {
          _trackingData = data;
          _isLoading = false;
        });
        _updateMarkers(data);

        if (data.driverLocation != null) {
          _getPolyline(
            LatLng(
                data.driverLocation!.latitude, data.driverLocation!.longitude),
            LatLng(data.destinationLocation.latitude,
                data.destinationLocation.longitude),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Tracking Error: $e");

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Handle 401 Unauthorized
        if (e.toString().contains('401')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi Anda telah berakhir. Silakan login kembali.'),
              backgroundColor: Colors.red,
            ),
          );
          // Cancel polling
          _timer?.cancel();
          // Navigate to login
          Navigator.of(context).pushReplacementNamed('/login');
        } else {
          // Handle other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data tracking: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _updateMarkers(TrackingResponse data) {
    // Marker Lokasi Tujuan (Rumah Mitra)
    final destination = LatLng(
        data.destinationLocation.latitude, data.destinationLocation.longitude);
    _markers[const MarkerId("destination")] = Marker(
      markerId: const MarkerId("destination"),
      position: destination,
      infoWindow: const InfoWindow(title: "Lokasi Saya"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    // Marker Lokasi Driver (Jika sudah ada)
    if (data.driverLocation != null) {
      final driverPos =
          LatLng(data.driverLocation!.latitude, data.driverLocation!.longitude);
      _markers[const MarkerId("driver")] = Marker(
        markerId: const MarkerId("driver"),
        position: driverPos,
        infoWindow:
            InfoWindow(title: "Driver: ${data.driver?.name ?? 'Kurir'}"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }
  }

  // Perbaikan Sintaks Polyline untuk versi flutter_polyline_points terbaru
  void _getPolyline(LatLng origin, LatLng dest) async {
    // 1. Inisialisasi PolylinePoints dengan API Key langsung di sini
    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleMapsApiKey);

    // 2. Gunakan PolylineRequest tanpa mengulang parameter API Key di bawah
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      if (mounted) {
        setState(() {
          const id = PolylineId("poly");
          polylines[id] = Polyline(
            polylineId: id,
            color: AppColors.primary,
            points: polylineCoordinates,
            width: 5,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order #${widget.orderId}'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _trackingData != null
                        ? LatLng(_trackingData!.destinationLocation.latitude,
                            _trackingData!.destinationLocation.longitude)
                        : const LatLng(-6.2000, 106.8166),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                  polylines: Set<Polyline>.of(polylines.values),
                  markers: Set<Marker>.of(_markers.values),
                  myLocationButtonEnabled: false,
                  padding: const EdgeInsets.only(
                      bottom: 150), // Agar marker tidak tertutup Card
                ),
                _buildOverlayStatus(),
              ],
            ),
    );
  }

  Widget _buildOverlayStatus() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.local_shipping,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trackingData?.driver?.name ?? "Menunggu Driver",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _trackingData!.orderStatus
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_trackingData?.distanceKm != null) ...[
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                        Icons.social_distance,
                        "${_trackingData!.distanceKm!.toStringAsFixed(1)} KM",
                        "Jarak"),
                    _buildInfoItem(
                        Icons.access_time,
                        "${_trackingData!.estimatedMinutes ?? '--'} Min",
                        "Estimasi"),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
