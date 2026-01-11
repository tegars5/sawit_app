import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/models/order.dart';
import '../../../core/services/storage_service.dart';
import '../providers/order_provider.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _scrollController = ScrollController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() async {
    final orderProvider = context.read<OrderProvider>();

    // ✅ Get actual token from storage
    final token = await StorageService.getToken();
    if (token != null) {
      orderProvider.setToken(token);
      orderProvider.loadOrders(refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<OrderProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'on_delivery':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = null);
                    orderProvider.filterByStatus(null);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _selectedStatus == 'pending',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'pending');
                    orderProvider.filterByStatus('pending');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Confirmed'),
                  selected: _selectedStatus == 'confirmed',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'confirmed');
                    orderProvider.filterByStatus('confirmed');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('On Delivery'),
                  selected: _selectedStatus == 'on_delivery',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'on_delivery');
                    orderProvider.filterByStatus('on_delivery');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _selectedStatus == 'completed',
                  onSelected: (selected) {
                    setState(() => _selectedStatus = 'completed');
                    orderProvider.filterByStatus('completed');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: orderProvider.orders.isEmpty && orderProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : orderProvider.orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start shopping to create your first order',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            orderProvider.loadOrders(refresh: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: orderProvider.orders.length +
                              (orderProvider.hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= orderProvider.orders.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final order = orderProvider.orders[index];
                            return _OrderCard(
                              order: order,
                              currencyFormat: currencyFormat,
                              statusColor: _getStatusColor(order.status),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderDetailScreen(
                                      orderId: order.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat currencyFormat;
  final Color statusColor;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.currencyFormat,
    required this.statusColor,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderCode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.destinationAddress,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    currencyFormat.format(order.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
