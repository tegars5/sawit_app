Subject: RE: Backend Fix Request - Real-time Distance & ETA

Halo Tim Front End / Mobile Dev,

Terima kasih atas masukannya.

Kami sudah melakukan update pada method OrderController::tracking dan menambahkan helper calculateDistance (Haversine Formula) sesuai request.

Changes Applied:

Dynamic Calculation: Backend sekarang menghitung sisa jarak (distance_km) dan estimasi waktu (estimated_minutes) berdasarkan posisi real-time driver (driverLat, driverLng) ke tujuan.
Safety Buffer: Ditambahkan buffer 40% pada jarak straight-line untuk mengakomodasi belokan jalan.
Fallback: Jika driver belum mengirim lokasi, sistem fallback ke data statis distance_km asli dari order.
Response JSON sekarang akan memberikan nilai yang dinamis dan semakin kecil saat driver mendekati tujuan. 🚗🏁

Silakan ditest kembali. Thanks!
