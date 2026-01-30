import 'dart:async';
import 'dart:math';
import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/theme.dart';

class DeliveryMapView extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final Stream<Position>? locationStream;
  final VoidCallback? onCenterLocation;

  const DeliveryMapView({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    this.locationStream,
    this.onCenterLocation,
  });

  @override
  State<DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<DeliveryMapView> {
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  StreamSubscription<Position>? _locationSubscription;

  // Simulation mode
  Timer? _simulationTimer;
  List<LatLng> _routeCoordinates = [];
  int _currentRouteIndex = 0;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _listenToLocationUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _simulationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    // Request location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    // Get initial location
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _updateMarkers();
      _fitBounds();
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _listenToLocationUpdates() {
    if (widget.locationStream != null) {
      _locationSubscription = widget.locationStream!.listen((position) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMarkers();
      });
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(
      IconData iconData, Color color) async {
    final pictureRecorder = dart_ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(100, 100); // Marker size

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw icon with distinct color and shadow for visibility
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 80, // Larger icon since no background
        fontFamily: iconData.fontFamily,
        color: color,
        shadows: const [
          Shadow(
            offset: Offset(2, 2),
            blurRadius: 3,
            color: Colors.black38,
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: dart_ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _updateMarkers() async {
    // Create custom icons
    final destinationIcon = await _createCustomMarkerBitmap(
      Icons.place, // Pin icon
      Colors.red,
    );

    final driverIcon = await _createCustomMarkerBitmap(
      Icons.local_shipping, // Truck icon
      Colors.blue, // Primary color
    );

    if (!mounted) return;

    setState(() {
      _markers.clear();

      // Destination marker
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.destinationLat, widget.destinationLng),
          icon: destinationIcon,
          infoWindow: const InfoWindow(title: 'Lokasi Tujuan'),
          anchor: const Offset(0.5, 0.5), // Center anchor for circular marker
        ),
      );

      // Driver marker (if location available)
      if (_driverLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon: driverIcon,
            infoWindow: const InfoWindow(title: 'Posisi Anda'),
            anchor: const Offset(0.5, 0.5),
            zIndex: 2, // Map driver on top
          ),
        );
      }
    });
  }

  void _fitBounds() {
    if (_mapController == null || _driverLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_driverLocation!.latitude, widget.destinationLat),
        min(_driverLocation!.longitude, widget.destinationLng),
      ),
      northeast: LatLng(
        max(_driverLocation!.latitude, widget.destinationLat),
        max(_driverLocation!.longitude, widget.destinationLng),
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  /// Draw route polyline from driver to destination
  Future<void> _drawRoute() async {
    if (_driverLocation == null) return;

    try {
      // Google Directions API
      const apiKey = 'AIzaSyDQOtvxYHnviEl-e_aQjamwVH8bQZnwh8U';
      final origin =
          '${_driverLocation!.latitude},${_driverLocation!.longitude}';
      final destination = '${widget.destinationLat},${widget.destinationLng}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&destination=$destination&key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylineEncoded = route['overview_polyline']['points'];

          // Decode polyline using static method
          final List<PointLatLng> result =
              PolylinePoints.decodePolyline(polylineEncoded);

          final List<LatLng> polylineCoordinates = result
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          if (mounted) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: const Color(0xFF00C853), // Green color like Grab/Gojek
                  width: 5,
                  points: polylineCoordinates,
                ),
              );
              // Store route coordinates for simulation
              _routeCoordinates = polylineCoordinates;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  /// Start route simulation
  void _startSimulation() {
    if (_routeCoordinates.isEmpty || _isSimulating) return;

    setState(() {
      _isSimulating = true;
      _currentRouteIndex = 0;
    });

    // Move every 2 seconds
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentRouteIndex >= _routeCoordinates.length - 1) {
        _stopSimulation();
        return;
      }

      setState(() {
        _currentRouteIndex++;
        _driverLocation = _routeCoordinates[_currentRouteIndex];
      });

      _updateMarkers();
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_driverLocation!),
      );
    });
  }

  /// Stop route simulation
  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_driverLocation != null) {
      _fitBounds();
      _drawRoute(); // Draw route when map is created
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _centerOnDriver() {
    if (_driverLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_driverLocation!),
      );
    }
    widget.onCenterLocation?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while getting initial location
    if (_isLoading || _driverLocation == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Memuat peta...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _driverLocation!,
            zoom: 14,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // Zoom Controls
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 16,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.add,
                onPressed: _zoomIn,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
              ),
            ],
          ),
        ),

        // Center Location Button
        Positioned(
          right: 16,
          bottom: 80, // Moved up to make room for simulation button
          child: _MapButton(
            icon: Icons.my_location,
            onPressed: _centerOnDriver,
            backgroundColor: AppColors.primary,
            iconColor: Colors.white,
          ),
        ),

        // Simulation Control Button
        Positioned(
          right: 16,
          bottom: 16,
          child: _MapButton(
            icon: _isSimulating ? Icons.stop : Icons.play_arrow,
            onPressed: _isSimulating ? _stopSimulation : _startSimulation,
            backgroundColor: _isSimulating ? Colors.red : Colors.orange,
            iconColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const _MapButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor ?? Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: iconColor ?? Colors.black87,
            size: 24,
          ),
        ),
      ),
    );
  }
}
