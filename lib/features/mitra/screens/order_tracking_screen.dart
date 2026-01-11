import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/launcher_helper.dart';
import '../../../core/models/tracking_response.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final ApiClient _apiClient = ApiClient();
  TrackingResponse? _tracking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  Future<void> _loadTracking() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final tracking = await _apiClient.trackOrder(widget.orderId);

      setState(() {
        _tracking = tracking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        actions: [
          IconButton(
            onPressed: _loadTracking,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('Error loading tracking'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadTracking,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tracking == null
                  ? const Center(child: Text('No tracking data'))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Map Placeholder
                          Container(
                            height: 300,
                            color: AppColors.surfaceVariant,
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map,
                                        size: 64,
                                        color:
                                            AppColors.primary.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Map View',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Google Maps integration coming soon',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_tracking!.driverLocation != null)
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  color: AppColors.primary,
                                                  size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Driver Location',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Lat: ${_tracking!.driverLocation!.latitude.toStringAsFixed(4)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          Text(
                                            'Lng: ${_tracking!.driverLocation!.longitude.toStringAsFixed(4)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Tracking Info
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Order Status
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline,
                                                color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Order Status',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildStatusTimeline(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Driver Info
                                if (_tracking!.driver != null)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.person,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Driver Information',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              const CircleAvatar(
                                                radius: 30,
                                                backgroundColor:
                                                    AppColors.primary,
                                                child: Icon(Icons.person,
                                                    color: Colors.white),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _tracking!.driver!.name,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _tracking!
                                                              .driver!.phone ??
                                                          '-',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.phone),
                                                onPressed: () async {
                                                  if (_tracking!
                                                          .driver?.phone !=
                                                      null) {
                                                    try {
                                                      await LauncherHelper
                                                          .makePhoneCall(
                                                              _tracking!.driver!
                                                                  .phone!);
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  'Could not make call: $e')),
                                                        );
                                                      }
                                                    }
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Driver phone number not available')),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                // Delivery Info
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.local_shipping,
                                                color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delivery Information',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInfoRow('Distance',
                                            '${_tracking!.distanceKm ?? '-'} km'),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Estimated Time',
                                            _tracking!.estimatedMinutes != null
                                                ? '${_tracking!.estimatedMinutes} min'
                                                : '-'),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          'Last Updated',
                                          DateFormat('dd MMM yyyy, HH:mm')
                                              .format(DateTime.now()),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatusTimeline() {
    final statuses = ['pending', 'confirmed', 'on_delivery', 'completed'];
    final currentIndex = statuses.indexOf(_tracking!.orderStatus.toLowerCase());

    return Column(
      children: List.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.circle,
                    color: isCompleted ? Colors.white : AppColors.textHint,
                    size: 16,
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
