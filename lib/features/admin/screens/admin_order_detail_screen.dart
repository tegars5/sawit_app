import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/models/driver.dart';
import '../../../core/services/storage_service.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
  });
  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final ApiClient _apiClient = ApiClient();
  Order? _order;
  bool _isLoading = true;
  String? _error;

  // PDF selection state
  String? _selectedPdfPath;
  String? _selectedPdfName;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    final token = await StorageService.getToken();

    if (token != null) {
      _apiClient.setToken(token);
    }

    await _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final order = await _apiClient.getAdminOrder(widget.orderId);
      setState(() {
        _order = order;
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
        title: Text('Order #${widget.orderId}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrderDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrderDetail,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Code & Status
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order Code',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      _buildStatusChip(_order!.status),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _order!.orderCode,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Created: ${DateFormat('dd MMM yyyy, HH:mm').format(_order!.createdAt)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Delivery Address
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delivery Address',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_order!.destinationAddress),
                                  if (_order!.distanceKm != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Distance: ${_order!.distanceKm!.toStringAsFixed(2)} km',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Order Items
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Items',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  if (_order!.orderItems != null)
                                    ...(_order!.orderItems!.map((item) =>
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.product?.name ?? 'Product'} x${item.quantity}',
                                                ),
                                              ),
                                              Text(
                                                'Rp ${NumberFormat('#,###').format(item.subtotal)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Total Amount & Payment
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Amount',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'Rp ${NumberFormat('#,###').format(_order!.totalAmount)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (_order!.payment != null) ...[
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Payment Status'),
                                        _buildPaymentStatusChip(
                                            _order!.payment!.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Payment Method'),
                                        Text(_order!.payment!.paymentMethod),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Driver Info (if assigned)
                          if (_order!.deliveryOrder?.driver != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_shipping,
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
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _order!.deliveryOrder!.driver!
                                                    .name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                _order!.deliveryOrder!.driver!
                                                        .phone ??
                                                    '-',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.orange),
                                    const SizedBox(width: 12),
                                    const Text('No driver assigned yet'),
                                  ],
                                ),
                              ),
                            ),
                          // Action Buttons
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'confirmed':
        color = Colors.blue;
        break;
      case 'on_delivery':
        color = Colors.purple;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildPaymentStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  // Build action buttons for driver assignment and waybill
  Widget _buildActionButtons() {
    // Only show if order has payment and is paid
    if (_order!.payment == null || _order!.payment!.status != 'paid') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Assign Driver button (if no driver assigned yet)
          if (_order!.deliveryOrder?.driver == null &&
              (_order!.status == 'pending' || _order!.status == 'confirmed'))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showDriverPicker,
                icon: const Icon(Icons.local_shipping),
                label: const Text('Assign Driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          // View Waybill PDF button (if driver assigned)
          if (_order!.deliveryOrder?.driver != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openWaybillPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View Waybill PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Open waybill PDF in external browser
  Future<void> _openWaybillPdf() async {
    try {
      final String pdfUrl = _apiClient.getWaybillPdfUrl(_order!.id);

      print('🔍 Opening waybill PDF in browser...');
      print('📡 URL: $pdfUrl');

      final url = Uri.parse(pdfUrl);

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open PDF');
      }

      print('✅ PDF opened in external browser');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open waybill: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Show driver selection modal
  Future<void> _showDriverPicker() async {
    try {
      final drivers = await _apiClient.getAvailableDrivers();

      if (!mounted) return;

      if (drivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No drivers available at the moment')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          builder: (context, scrollController) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Driver',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(driver.name),
                      subtitle: Text(
                          '${driver.vehicleType} - ${driver.vehiclePlate}'),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmAssignDriver(driver);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading drivers: $e')),
      );
    }
  }

  // Pick PDF file for waybill
  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        // Check file size (5MB limit)
        if (result.files.single.size > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File terlalu besar! Maksimal 5MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedPdfPath = result.files.single.path;
          _selectedPdfName = result.files.single.name;
        });

        print(
            '✅ PDF selected: $_selectedPdfName (${(result.files.single.size / 1024).toStringAsFixed(2)} KB)');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  // Confirm driver assignment
  Future<void> _confirmAssignDriver(Driver driver) async {
    // Reset selected PDF
    setState(() {
      _selectedPdfPath = null;
      _selectedPdfName = null;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign ${driver.name} to this order?'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Upload Waybill PDF:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickPdfFile();
                  setDialogState(() {}); // Refresh dialog
                },
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _selectedPdfName ?? 'Select PDF File',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
              ),
              if (_selectedPdfName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPdfName!,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _selectedPdfPath != null
                  ? () => Navigator.pop(context, true)
                  : null, // Disable if no PDF selected
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && _selectedPdfPath != null) {
      await _assignDriver(driver.id);
    }
  }

  // Assign driver to order
  Future<void> _assignDriver(int driverId) async {
    try {
      setState(() => _isLoading = true);

      // Assign driver with PDF
      await _apiClient.assignDriver(
        _order!.id,
        driverId,
        _selectedPdfPath, // Pass PDF path
      );

      // Reload order detail to get complete data (including order_items)
      await _loadOrderDetail();

      setState(() {
        _selectedPdfPath = null; // Clear after success
        _selectedPdfName = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver assigned and waybill uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning driver: $e')),
      );
    }
  }
}
