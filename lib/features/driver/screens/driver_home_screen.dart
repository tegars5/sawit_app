import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../providers/driver_order_provider.dart';
import 'driver_delivery_list_screen.dart';
import 'driver_profile_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _DashboardOverview(),
    const DriverDeliveryListScreen(),
    const DriverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardOverview extends StatefulWidget {
  const _DashboardOverview();

  @override
  State<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<_DashboardOverview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final driverProvider = context.read<DriverOrderProvider>();

    if (authService.currentUser != null) {
      // Initialize token from SharedPreferences first
      await driverProvider.initializeToken();
      // Then load orders
      await driverProvider.loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final driverProvider = context.watch<DriverOrderProvider>();
    final user = authService.currentUser!;

    final activeOrders = driverProvider.orders
        .where((o) =>
            o.deliveryOrder != null &&
            (o.deliveryOrder!.status == 'assigned' ||
                o.deliveryOrder!.status == 'picked_up'))
        .length;

    final completedOrders = driverProvider.orders
        .where((o) =>
            o.deliveryOrder != null && o.deliveryOrder!.status == 'delivered')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.local_shipping,
                          size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Availability Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Availability Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driverProvider.isAvailable
                              ? 'Available for deliveries'
                              : 'Not available',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: driverProvider.isAvailable
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                    Switch(
                      value: driverProvider.isAvailable,
                      onChanged: (value) async {
                        final success =
                            await driverProvider.toggleAvailability(value);
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update availability'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_shipping,
                    title: 'Active Orders',
                    value: '$activeOrders',
                    color: AppColors.primary,
                    onTap: () {
                      // Navigate to deliveries tab
                      final state = context
                          .findAncestorStateOfType<_DriverHomeScreenState>();
                      state?.setState(() {
                        state._currentIndex = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    title: 'Completed',
                    value: '$completedOrders',
                    color: AppColors.success,
                    onTap: () {
                      // Navigate to deliveries tab
                      final state = context
                          .findAncestorStateOfType<_DriverHomeScreenState>();
                      state?.setState(() {
                        state._currentIndex = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.local_shipping,
              label: 'View Deliveries',
              onTap: () {
                final state =
                    context.findAncestorStateOfType<_DriverHomeScreenState>();
                state?.setState(() {
                  state._currentIndex = 1;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: color.withOpacity(0.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
