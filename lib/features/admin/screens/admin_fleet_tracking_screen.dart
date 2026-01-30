import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../config/theme.dart';
import '../../../core/models/admin_dashboard_summary.dart';

class AdminFleetTrackingScreen extends StatefulWidget {
  final List<DriverLocation> activeDrivers;

  const AdminFleetTrackingScreen({
    super.key,
    required this.activeDrivers,
  });

  @override
  State<AdminFleetTrackingScreen> createState() =>
      _AdminFleetTrackingScreenState();
}

class _AdminFleetTrackingScreenState extends State<AdminFleetTrackingScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  void _loadMarkers() {
    if (widget.activeDrivers.isNotEmpty) {
      for (var driver in widget.activeDrivers) {
        _markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.driverId}'),
            position: LatLng(driver.latitude, driver.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: driver.driverName,
              snippet: 'Order #${driver.orderId}',
            ),
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Fit bounds to show all markers
    if (widget.activeDrivers.isNotEmpty) {
      LatLngBounds bounds;
      var activeLocations = widget.activeDrivers;

      double minLat = activeLocations.first.latitude;
      double maxLat = activeLocations.first.latitude;
      double minLng = activeLocations.first.longitude;
      double maxLng = activeLocations.first.longitude;

      for (var driver in activeLocations) {
        if (driver.latitude < minLat) minLat = driver.latitude;
        if (driver.latitude > maxLat) maxLat = driver.latitude;
        if (driver.longitude < minLng) minLng = driver.longitude;
        if (driver.longitude > maxLng) maxLng = driver.longitude;
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Add delay to allow map to render
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-6.175392, 106.827153), // Jakarta
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Custom Back Button
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
            ),
          ),

          // Bottom Sheet with Driver List
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Drag Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.activeDrivers.length} Armada Aktif',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: widget.activeDrivers.isEmpty
                          ? const Center(
                              child: Text('Tidak ada armada aktif saat ini'),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: widget.activeDrivers.length,
                              itemBuilder: (context, index) {
                                final driver = widget.activeDrivers[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Icon(Icons.person,
                                        color: Colors.white, size: 20),
                                  ),
                                  title: Text(
                                    driver.driverName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                      'Mengantar Order #${driver.orderId}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.my_location,
                                        color: AppColors.primary),
                                    onPressed: () {
                                      _mapController.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(driver.latitude,
                                              driver.longitude),
                                          15,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
