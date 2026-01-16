<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Surat Tugas Pengiriman - {{ $order->order_code }}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'DejaVu Sans', Arial, sans-serif;
            font-size: 12px;
            line-height: 1.6;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 30px;
            border-bottom: 3px solid #2c5f2d;
            padding-bottom: 15px;
        }
        
        .header h1 {
            font-size: 20px;
            color: #2c5f2d;
            margin-bottom: 5px;
        }
        
        .header h2 {
            font-size: 16px;
            color: #555;
            margin-bottom: 10px;
        }
        
        .order-code {
            font-size: 14px;
            font-weight: bold;
            color: #333;
        }
        
        .info-section {
            margin-bottom: 20px;
        }
        
        .info-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        
        .info-table td {
            padding: 8px;
            border: 1px solid #ddd;
        }
        
        .info-table td:first-child {
            width: 30%;
            background-color: #f5f5f5;
            font-weight: bold;
        }
        
        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        
        .items-table th {
            background-color: #2c5f2d;
            color: white;
            padding: 10px;
            text-align: left;
            border: 1px solid #2c5f2d;
        }
        
        .items-table td {
            padding: 8px;
            border: 1px solid #ddd;
        }
        
        .items-table tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        
        .notes {
            background-color: #fff9e6;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        
        .notes h3 {
            color: #f57c00;
            margin-bottom: 10px;
            font-size: 14px;
        }
        
        .notes ul {
            margin-left: 20px;
        }
        
        .notes li {
            margin-bottom: 5px;
        }
        
        .signature-section {
            margin-top: 50px;
            display: table;
            width: 100%;
        }
        
        .signature-box {
            display: table-cell;
            width: 50%;
            text-align: center;
            padding: 10px;
        }
        
        .signature-line {
            margin-top: 60px;
            border-top: 1px solid #333;
            padding-top: 5px;
            display: inline-block;
            width: 200px;
        }
        
        .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 10px;
            color: #888;
            border-top: 1px solid #ddd;
            padding-top: 10px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>CANGKANG SAWIT</h1>
        <h2>SURAT TUGAS PENGIRIMAN</h2>
        <p class="order-code">No: {{ $order->order_code }}</p>
    </div>

    <div class="info-section">
        <table class="info-table">
            <tr>
                <td>Driver</td>
                <td>{{ $order->driver->name ?? '-' }}</td>
            </tr>
            <tr>
                <td>No. Telepon Driver</td>
                <td>{{ $order->driver->phone ?? '-' }}</td>
            </tr>
            <tr>
                <td>Customer</td>
                <td>{{ $order->user->name }}</td>
            </tr>
            <tr>
                <td>No. Telepon Customer</td>
                <td>{{ $order->user->phone ?? '-' }}</td>
            </tr>
            <tr>
                <td>Alamat Tujuan</td>
                <td>{{ $order->destination_address }}</td>
            </tr>
            <tr>
                <td>Tanggal Penugasan</td>
                <td>{{ $order->assigned_at ? $order->assigned_at->format('d F Y, H:i') : $order->created_at->format('d F Y, H:i') }}</td>
            </tr>
            @if($order->distance_km)
            <tr>
                <td>Estimasi Jarak</td>
                <td>{{ number_format($order->distance_km, 1) }} km</td>
            </tr>
            @endif
            @if($order->estimated_minutes)
            <tr>
                <td>Estimasi Waktu</td>
                <td>{{ $order->estimated_minutes }} menit</td>
            </tr>
            @endif
        </table>
    </div>

    <h3 style="margin-bottom: 10px; color: #2c5f2d;">Daftar Muatan:</h3>
    <table class="items-table">
        <thead>
            <tr>
                <th style="width: 10%;">No</th>
                <th style="width: 50%;">Nama Produk</th>
                <th style="width: 20%;">Jumlah</th>
                <th style="width: 20%;">Satuan</th>
            </tr>
        </thead>
        <tbody>
            @foreach($order->orderItems as $index => $item)
            <tr>
                <td style="text-align: center;">{{ $index + 1 }}</td>
                <td>{{ $item->product->name }}</td>
                <td style="text-align: right;">{{ number_format($item->quantity, 2) }}</td>
                <td>Ton</td>
            </tr>
            @endforeach
            <tr style="background-color: #f0f0f0; font-weight: bold;">
                <td colspan="2" style="text-align: right;">Total Muatan:</td>
                <td style="text-align: right;">{{ number_format($order->orderItems->sum('quantity'), 2) }}</td>
                <td>Ton</td>
            </tr>
        </tbody>
    </table>

    <div class="notes">
        <h3>⚠️ CATATAN PENTING UNTUK DRIVER:</h3>
        <ul>
            <li>Driver WAJIB mengikuti rute yang telah ditentukan sistem</li>
            <li>Pastikan muatan dalam kondisi baik dan aman selama perjalanan</li>
            <li>Hubungi customer minimal 30 menit sebelum sampai lokasi</li>
            <li>Lakukan foto dokumentasi saat loading dan unloading</li>
            <li>Update status pengiriman secara real-time melalui aplikasi</li>
            <li>Segera laporkan jika ada kendala atau masalah selama perjalanan</li>
        </ul>
    </div>

    <div class="signature-section">
        <div class="signature-box">
            <p><strong>Mengetahui,</strong></p>
            <p><strong>Admin</strong></p>
            <div class="signature-line">
                <p>(___________________)</p>
            </div>
        </div>
        <div class="signature-box">
            <p><strong>Menerima Tugas,</strong></p>
            <p><strong>Driver</strong></p>
            <div class="signature-line">
                <p>{{ $order->driver->name ?? '___________________' }}</p>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>Dokumen ini digenerate otomatis oleh sistem Cangkang Sawit</p>
        <p>Tanggal Cetak: {{ now()->format('d F Y, H:i:s') }}</p>
    </div>
</body>
</html>
