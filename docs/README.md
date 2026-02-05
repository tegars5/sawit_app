# Dokumentasi

## Diagram Aktivitas (Activity Diagram)

Diagram aktivitas untuk **Alur Pemesanan Produk** ini memvisualisasikan proses mulai dari pemilihan produk hingga pembayaran selesai.

### Cara Melihat

1.  Buka [Draw.io / Diagrams.net](https://app.diagrams.net/).
2.  Klik **File** > **Open From** > **Device...**
3.  Pilih file `activity_diagram.xml` yang berada di folder ini.

### Penjelasan Alur

- **Pengguna (Mitra)**: Memilih produk, memasukkan alamat, memilih metode pembayaran.
- **Sistem (Aplikasi & Backend)**: Memvalidasi stok/alamat, menginisialisasi pembayaran via API, memperbarui status pesanan.
- **Payment Gateway**: Memproses transaksi (Tripay).

## Diagram Tracking Real-Time

File: `activity_diagram_tracking.xml`

### Penjelasan Alur

- **Pengguna**: Membuka halaman tracking dari detail pesanan.
- **Aplikasi**: Mengambil data lokasi awal dan memunculkan peta.
- **Polling Loop**: Aplikasi secara otomatis me-refresh data lokasi setiap 10 detik.
- **Update UI**: Marker driver bergerak secara real-time di peta tanpa perlu refresh halaman manual.

## Diagram Sequence Login & Register

File: `sequence_diagram_auth.puml` (PlantUML)

> **Catatan:** Untuk melihat file `.puml`, Anda bisa menggunakan extension **PlantUML** di VS Code atau copy kodenya ke [PlantText](https://www.planttext.com/).

### Penjelasan Alur (Login)

1. **User**: Input Email & Password.
2. **Aplikasi**: Mengirim data ke `ApiClient`.
3. **Server**: Memvalidasi kredensial di database.
4. **Valid**: Server mengembalikan Token, Aplikasi menyimpan Token, User masuk Dashboard.
5. **Invalid**: Server mengembalikan error 401, Aplikasi menampilkan pesan error.

### Penjelasan Alur (Register)

1. **User**: Input Nama, Email, Password.
2. **Aplikasi**: Mengirim data registrasi ke Server.
3. **Server**: Membuat user baru dan langsung mengembalikan Token (Auto Login).
4. **Aplikasi**: Menyimpan Token dan mengarahkan user ke Dashboard.

## Diagram Sequence Buat Pesanan (Order)

File: `sequence_diagram_order.puml` (PlantUML)

### Penjelasan Alur

1. **User**: Memilih produk dan masuk keranjang.
2. **Checkout**: Mengisi alamat dan validasi.
3. **Backend**: Membuat pesanan status "Pending" dan meminta URL pembayaran ke Tripay.
4. **Gateway**: User membayar, lalu sistem mengupdate status pesanan menjadi "Processing".

## Diagram Sequence Pembayaran (Callback Tripay)

File: `sequence_diagram_payment.puml` (PlantUML)

### Penjelasan Alur

1. **Tripay**: Mengirim notifikasi (Webhook) ke server kita saat user selesai membayar.
2. **Backend**: Memvalidasi keamanan data (Signature).
3. **Database**: Jika valid, status pesanan diupdate otomatis (misal: Pending -> Processing).
4. **Notifikasi**: User mendapat notifikasi pembayaran berhasil.

## Diagram Sequence Tracking Real-time

File: `sequence_diagram_tracking.puml` (PlantUML)

### Penjelasan Alur

1. **Buka Halaman**: User membuka peta, aplikasi mengambil data lokasi awal.
2. **Looping (Tiap 10 Detik)**: Aplikasi otomatis bertanya ke server "Driver ada di mana sekarang?".
3. **Update Peta**: Server memberi koordinat baru, aplikasi menggeser ikon motor tanpa perlu refresh halaman.
4. **Keluar**: Saat user kembali, timer berhenti agar tidak boros baterai.

## Diagram Sequence Kelola Produk (Admin)

File: `sequence_diagram_product.puml` (PlantUML)

### Penjelasan Alur

1. **Tambah Produk**: Admin upload foto & data -> Server simpan gambar & database -> Sukses.
2. **Edit Produk**: Admin ubah harga/stok -> Server update database -> Sukses.
3. **Hapus Produk**: Admin hapus -> Server remove dari database -> List di-refresh.

## Diagram Sequence Kelola Driver (Admin)

File: `sequence_diagram_driver.puml` (PlantUML)

### Penjelasan Alur

1. **Tambah Driver**: Admin input data (Nama, Plat Nomor) -> Server validasi & simpan -> Sukses.
2. **Edit Driver**: Admin update kendaraan/no hp -> Server update profile -> Sukses.
3. **Hapus Driver**: Admin hapus akun driver -> Server remove -> List di-refresh.
