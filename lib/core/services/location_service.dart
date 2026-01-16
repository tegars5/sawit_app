import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';

/// Service untuk mengelola tracking lokasi driver secara real-time.
/// Menggunakan Timer.periodic untuk mengirim data berkala ke server.
class LocationService {
  final ApiClient _apiClient;
  Timer? _locationTimer;
  bool _isTracking = false;
  int? _currentOrderId;

  LocationService(this._apiClient);

  /// Getter untuk mengecek apakah status tracking sedang aktif.
  bool get isTracking => _isTracking;

  /// Getter untuk mengetahui Order ID mana yang sedang dilacak.
  int? get currentOrderId => _currentOrderId;

  /// Memeriksa dan meminta izin akses lokasi (GPS) kepada user.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cek apakah layanan lokasi (GPS) di HP aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ GPS service tidak aktif pada perangkat');
      return false;
    }

    // 2. Cek status izin aplikasi
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Izin lokasi ditolak oleh user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
          '❌ Izin lokasi ditolak permanen. User harus ubah di pengaturan HP');
      return false;
    }

    debugPrint('✅ Izin lokasi diberikan');
    return true;
  }

  /// Memulai proses tracking lokasi secara berkala setiap 12 detik.
  /// @param orderId - ID dari tabel orders yang akan diupdate koordinatnya.
  Future<bool> startTracking(int orderId) async {
    if (_isTracking) {
      debugPrint('⚠️ Tracking sudah berjalan untuk Order #$_currentOrderId');
      return true;
    }

    // Jalankan pengecekan izin terlebih dahulu
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return false;

    _isTracking = true;
    _currentOrderId = orderId;

    debugPrint('🚀 Memulai siklus tracking untuk Order #$orderId');

    // Pengiriman lokasi pertama kali secara instan (tanpa tunggu timer)
    _sendCurrentLocation(orderId);

    // Set up timer untuk pengiriman otomatis selanjutnya
    _locationTimer = Timer.periodic(
      const Duration(seconds: 12),
      (timer) async {
        if (!_isTracking) {
          timer.cancel();
          return;
        }
        await _sendCurrentLocation(orderId);
      },
    );

    return true;
  }

  /// Fungsi internal untuk mengambil koordinat GPS dan mengirimnya ke ApiClient.
  Future<void> _sendCurrentLocation(int orderId) async {
    try {
      // Mengambil posisi dengan batas waktu (timeout) 7 detik
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      debugPrint(
          '📍 Posisi Driver: ${position.latitude}, ${position.longitude}');

      // Mengirim data ke Laravel Backend via ApiClient
      await _apiClient.updateOrderLocation(
        orderId: orderId,
        lat: position.latitude,
        lng: position.longitude,
      );

      debugPrint('✅ Data lokasi Order #$orderId berhasil masuk ke database');
    } on TimeoutException {
      // Jika GPS lemot (misal dalam gedung), jangan matikan timer, cukup log saja
      debugPrint(
          '⏱️ GPS Timeout: Sinyal lemah, mencoba lagi di siklus berikutnya.');
    } catch (e) {
      debugPrint('❌ Gagal mengirim lokasi: $e');

      // Jika error 401 (Unauthorized), artinya token expired. Hentikan tracking.
      if (e.toString().contains('401')) {
        debugPrint('🔒 Token Expired. Menghentikan tracking otomatis.');
        stopTracking();
      }
    }
  }

  /// Menghentikan pengiriman lokasi dan membersihkan timer.
  void stopTracking() {
    if (!_isTracking) {
      debugPrint('⚠️ Tidak ada tracking yang aktif untuk dihentikan');
      return;
    }

    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;

    debugPrint('🛑 Tracking dihentikan untuk Order #$_currentOrderId');
    _currentOrderId = null;
  }

  /// Membersihkan resource saat service tidak lagi digunakan.
  void dispose() {
    stopTracking();
    debugPrint('🗑️ LocationService disposed');
  }
}
