import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../providers/admin_dashboard_provider.dart';
import 'admin_driver_list_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_fleet_tracking_screen.dart';
import 'admin_product_list_screen.dart';
import 'dart:math' as math;

class AdminDashboardOverviewScreen extends StatefulWidget {
  const AdminDashboardOverviewScreen({super.key});

  @override
  State<AdminDashboardOverviewScreen> createState() =>
      _AdminDashboardOverviewScreenState();
}

class _AdminDashboardOverviewScreenState
    extends State<AdminDashboardOverviewScreen> {
  String _chartFilter = 'Mingguan';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authService = context.read<AuthService>();
      final dashboardProvider = context.read<AdminDashboardProvider>();

      if (authService.token != null) {
        dashboardProvider.setToken(authService.token!);
        dashboardProvider.loadDashboardSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser!;
    final dashboardProvider = context.watch<AdminDashboardProvider>();
    final summary = dashboardProvider.summary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: user.profilePicture != null
                              ? NetworkImage(user.profilePicture!)
                              : null,
                          child: user.profilePicture == null
                              ? const Icon(Icons.person,
                                  color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat Pagi,',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Stack(
                        children: [
                          const Icon(Icons.notifications_outlined,
                              color: Colors.black87),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Stats Grid
              if (dashboardProvider.isLoading && summary == null)
                const Center(child: CircularProgressIndicator())
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                  children: [
                    if (dashboardProvider.error != null)
                      Center(
                          child: Text('Error: ${dashboardProvider.error}',
                              style: const TextStyle(color: Colors.red))),
                    _buildStatCard(
                      context,
                      title: 'PENDING',
                      value: summary?.pendingOrders.toString() ?? '0',
                      subtitle: 'Butuh respon',
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                      bgColor: Colors.orange.shade50,
                    ),
                    _buildStatCard(
                      context,
                      title: 'PROSES',
                      value: summary?.processedOrders.toString() ?? '0',
                      subtitle: 'Sedang dikemas/jalan',
                      icon: Icons.sync,
                      color: Colors.blue,
                      bgColor: Colors.blue.shade50,
                    ),
                    _buildStatCard(
                      context,
                      title: 'DRIVER AKTIF',
                      value: summary?.activeDrivers.toString() ?? '0',
                      subtitle: 'Total ${summary?.totalDrivers ?? 0} Driver',
                      icon: Icons.local_shipping,
                      color: AppColors.primary,
                      bgColor: AppColors.primary.withValues(alpha: 0.1),
                      iconBgColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    _buildStatCard(
                      context,
                      title: 'TERLARIS',
                      value: summary?.bestSellingProduct ?? '-',
                      subtitle: summary?.bestSellingProductQty ?? '0 Ton',
                      icon: Icons.verified,
                      color: Colors.purple,
                      bgColor: Colors.purple.shade50,
                      isLargeValueText: false,
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // 3. Simple Chart Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tren Pesanan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Statistik harian minggu ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFilterButton('Mingguan'),
                              _buildFilterButton('Bulanan'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (summary != null) ...[
                      SizedBox(
                        height: 150,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final weeklyData = summary.weeklyOrders;
                            final maxVal = weeklyData.reduce(math.max);
                            final divisor =
                                maxVal > 0 ? maxVal.toDouble() : 1.0;
                            final days = [
                              'Sen',
                              'Sel',
                              'Rab',
                              'Kam',
                              'Jum',
                              'Sab',
                              'Min'
                            ];

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (index) {
                                final val = index < weeklyData.length
                                    ? weeklyData[index]
                                    : 0;
                                return _buildBar(days[index], val / divisor);
                              }),
                            );
                          },
                        ),
                      ),
                    ] else
                      const SizedBox(
                          height: 150,
                          child: Center(child: Text("Memuat grafik..."))),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Quick Actions
              const Text(
                'Tindakan Cepat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    context,
                    icon: Icons.add_circle,
                    label: 'Order Baru',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminOrderListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.person_add,
                    label: 'Add Driver',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDriverListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.inventory,
                    label: 'Cek Stok',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminProductListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.description,
                    label: 'Laporan',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminOrderListScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 5. Live Tracking Preview
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Live Tracking Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  // Navigate to Full Screen Fleet Tracking
                  if (summary?.activeFleetLocations != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminFleetTrackingScreen(
                          activeDrivers: summary!.activeFleetLocations,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  height: 180, // Slightly taller for better map view
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Real Map Background (Lite Mode)
                        IgnorePointer(
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(
                                  -6.175392, 106.827153), // Monas (Default)
                              zoom: 12,
                            ),
                            liteModeEnabled: true,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            myLocationButtonEnabled: false,
                            onMapCreated: (controller) {
                              controller.setMapStyle('''
                                [
                                  {
                                    "featureType": "poi",
                                    "stylers": [{"visibility": "off"}]
                                  },
                                  {
                                    "featureType": "transit",
                                    "stylers": [{"visibility": "off"}]
                                  }
                                ]
                                ''');
                            },
                            markers: (summary?.activeFleetLocations ?? [])
                                    .isEmpty
                                ? <Marker>{}
                                : summary!.activeFleetLocations.map((driver) {
                                    return Marker(
                                      markerId:
                                          MarkerId('driver_${driver.driverId}'),
                                      position: LatLng(
                                          driver.latitude, driver.longitude),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor
                                                  .hueOrange), // Orange fleet
                                    );
                                  }).toSet(),
                          ),
                        ),

                        // Gradient Overlay for readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Glassmorphic Info Card
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                // Truck Icon with Circle
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_shipping,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Armada Aktif',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        summary != null
                                            ? '${summary.activeFleetLocations.length} Driver Bertugas'
                                            : 'Memuat data...',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Chevron
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.grey[400],
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    Color? iconBgColor,
    bool isLargeValueText = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor ?? bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              // Optional: Add indicator/arrow here if needed
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11, // Slightly smaller title
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2), // Reduced spacing
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isLargeValueText ? 24 : 15, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10, // Slightly smaller subtitle
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _chartFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _chartFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8), // Reduced horizontal padding
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildBar(String label, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: heightFactor,
                    child: Container(
                      width: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(20), // More rounded square-ish look
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
