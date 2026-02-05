import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../config/theme.dart';
import '../providers/cart_provider.dart';
import 'checkout_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  bool _isProcessing = false;
  bool _isLocating = false;

  // Variabel untuk menampung koordinat asli dari GPS
  double? _selectedLat;
  double? _selectedLng;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Fungsi untuk mengambil lokasi GPS dan mengubahnya menjadi alamat teks
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // 1. Cek Service Lokasi Aktif/Tidak
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable them.';
      }

      // 2. Cek & Minta Izin GPS
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      // 3. Ambil Koordinat
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _selectedLat = position.latitude;
      _selectedLng = position.longitude;

      // 4. Reverse Geocoding (Koordinat -> Nama Jalan)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLat!,
        _selectedLng!,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Susun alamat yang rapi
        String formattedAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}";

        setState(() {
          _addressController.text = formattedAddress;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal mengambil lokasi: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  /// Coba convert alamat teks menjadi koordinat (Geocoding)
  Future<bool> _geocodeAddress(String address) async {
    setState(() => _isProcessing = true);
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        _selectedLat = locations.first.latitude;
        _selectedLng = locations.first.longitude;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi ditemukan pada peta!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        return true;
      } else {
        throw 'Alamat tidak ditemukan.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Gagal mendeteksi lokasi otomatis. Mohon perjelas alamat atau gunakan tombol GPS.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi: Jika koordinat belum ada (user ketik manual), coba cari via Geocoding
    if (_selectedLat == null || _selectedLng == null) {
      bool success = await _geocodeAddress(_addressController.text);
      if (!success)
        return; // Pesan error sudah ditampilkan di function _geocodeAddress
    }

    setState(() => _isProcessing = true);
    final cartProvider = context.read<CartProvider>();

    if (mounted) {
      setState(() => _isProcessing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPaymentScreen(
            cartItems: cartProvider.getOrderItems(),
            totalAmount: cartProvider.totalAmount,
            destinationAddress: _addressController.text.trim(),
            destinationLat: _selectedLat!,
            destinationLng: _selectedLng!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pesanan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section 1: Alamat Pengiriman
            _buildAddressCard(),
            const SizedBox(height: 16),

            // Section 2: Ringkasan Belanja
            _buildOrderSummaryCard(cartProvider),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(cartProvider),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Alamat Pengiriman',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Detail Alamat',
                hintText: 'Contoh: No Rumah, Nama Jalan, Kelurahan',
                prefixIcon: const Icon(Icons.home),
                // Tombol Ambil Lokasi GPS Otomatis
                suffixIcon: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.my_location,
                            color: AppColors.primary),
                        onPressed: _getCurrentLocation,
                        tooltip: "Ambil Lokasi GPS",
                      ),
              ),
              maxLines: 3,
              validator: (value) => value == null || value.isEmpty
                  ? 'Alamat tidak boleh kosong'
                  : null,
            ),
            if (_selectedLat != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "📍 Titik koordinat terkunci secara akurat",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(CartProvider cart) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Ringkasan Pesanan',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...cart.items.values.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${item.quantity}x ${item.product.name}',
                            style: const TextStyle(fontSize: 15)),
                      ),
                      Text(
                        'Rp ${item.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'Rp ${cart.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processCheckout,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Pilih Metode Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
