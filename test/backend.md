<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;

class AdminDashboardController extends Controller
{
    /**
     * Get dashboard summary statistics for admin
     * 
     * @return \Illuminate\Http\JsonResponse
     */
    public function summary(Request $request)
    {
        $user = auth()->user();

        // Check if user is admin
        if ($user->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized.',
            ], 403);
        }

        // Calculate order statistics efficiently using aggregation
        $orderStats = \DB::table('orders')
            ->selectRaw('
                COUNT(*) as total_orders,
                SUM(CASE WHEN status = "pending" THEN 1 ELSE 0 END) as pending_count,
                SUM(CASE WHEN status = "confirmed" THEN 1 ELSE 0 END) as confirmed_count,
                SUM(CASE WHEN status = "on_delivery" THEN 1 ELSE 0 END) as on_delivery_count,
                SUM(CASE WHEN status = "completed" THEN 1 ELSE 0 END) as completed_count
            ')
            ->first();

        // Count active partners (users with role 'mitra')
        $activePartners = \DB::table('users')
            ->where('role', 'mitra')
            ->count();

        // Calculate total inventory (sum of all product stock)
        $inventoryTons = \DB::table('products')
            ->sum('stock') ?? 0;

        // Get current timestamp
        $lastUpdatedAt = now()->toIso8601String();

        return response()->json([
            // Existing fields (for backward compatibility)
            'total_orders' => (int) $orderStats->total_orders,
            'in_delivery' => (int) $orderStats->on_delivery_count,
            'completed' => (int) $orderStats->completed_count,
            
            // New fields for enhanced dashboard
            'new_orders' => (int) $orderStats->pending_count,
            'pending_shipments' => (int) $orderStats->on_delivery_count,
            'active_partners' => (int) $activePartners,
            'inventory_tons' => (int) $inventoryTons,
            
            // Detailed order status breakdown
            'orders_completed' => (int) $orderStats->completed_count,
            'orders_processing' => (int) $orderStats->confirmed_count,
            'orders_in_transit' => (int) $orderStats->on_delivery_count,
            'orders_awaiting' => (int) $orderStats->pending_count,
            
            // Timestamp
            'last_updated_at' => $lastUpdatedAt,
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\DeliveryOrder;
use App\Models\User;
use App\Models\Waybill;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AdminOrderController extends Controller
{
    /**
     * Menampilkan semua pesanan untuk Admin dengan paginasi
     */
    public function index(Request $request)
    {
        if (auth()->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin access required.',
            ], 403);
        }
        
        $perPage = $request->input('per_page', 15);
        $status = $request->input('status');
        
        $query = Order::with(['orderItems.product', 'deliveryOrder.driver', 'user', 'payment']);
        
        if ($status) {
            $query->where('status', $status);
        }
        
        $orders = $query->latest()->paginate($perPage);
        
        return response()->json($orders);
    }

    /**
     * Menyetujui pesanan (Approved)
     */
    public function approve(Order $order, Request $request)
    {
        if (auth()->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin access required.',
            ], 403);
        }

        if ($order->status !== 'pending') {
            return response()->json([
                'message' => 'Only pending orders can be approved.',
            ], 400);
        }

        $order->update([
            'status' => 'confirmed',
        ]);
        
        // Kirim notifikasi jika service tersedia
        try {
            $notificationService = app(\App\Services\NotificationService::class);
            $notificationService->sendOrderNotification(
                $order,
                'Order Approved',
                "Your order {$order->order_code} has been approved by admin",
                'order.approved'
            );
        } catch (\Exception $e) {
            \Log::error("Notification failed: " . $e->getMessage());
        }
        
        return response()->json([
            'message' => 'Order approved successfully',
            'order'   => $order->load(['orderItems.product', 'deliveryOrder.driver', 'user']),
        ]);
    }

    /**
     * ✅ FIXED: Menampilkan detail pesanan dengan data Driver lengkap
     */
    public function show(Order $order)
    {
        try {
            // Memuat semua relasi termasuk deliveryOrder dan driver-nya
            $order->load([
                'user', 
                'orderItems.product', 
                'payment',
                'deliveryOrder.driver', // Kunci agar nama driver tidak "null" di Admin
                'waybill'               // Memuat data surat jalan
            ]);

            return response()->json([
                'success' => true,
                'data' => $order
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal memuat detail pesanan: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * ✅ FIXED: Menugaskan Driver dan membuat jatah order (DeliveryOrder)
     */
    public function assignDriver(Request $request, $id)
    {
        $request->validate([
            'driver_id' => 'required|exists:users,id',
            'waybill_pdf' => 'required|mimes:pdf|max:5120',
        ]);

        try {
            $order = Order::findOrFail($id);

            if ($request->hasFile('waybill_pdf')) {
                $file = $request->file('waybill_pdf');
                $fileName = 'waybill_' . $order->id . '_' . time() . '.' . $file->getClientOriginalExtension();
                $path = $file->storeAs('waybills', $fileName, 'public');

                // 1. Simpan ke tabel Waybills
                Waybill::updateOrCreate(
                    ['order_id' => $order->id],
                    [
                        'driver_id' => $request->driver_id,
                        'waybill_number' => 'WB-' . strtoupper(Str::random(10)),
                        'pdf_path' => $fileName, 
                    ]
                );

                // 2. Simpan ke tabel DeliveryOrders (Jatah Order Driver)
                DeliveryOrder::updateOrCreate(
                    ['order_id' => $order->id],
                    [
                        'driver_id' => $request->driver_id,
                        'status' => 'assigned',
                        'waybill_pdf' => $fileName,
                        'assigned_at' => now(),
                    ]
                );

                // 3. Update Status Order Utama
                $order->update(['status' => 'on_delivery']);

                // 4. Update Status Ketersediaan Driver
                User::where('id', $request->driver_id)->update(['availability_status' => 'busy']);

                return response()->json([
                    'success' => true,
                    'message' => 'Driver assigned successfully',
                    'data' => $order->load(['deliveryOrder.driver', 'waybill'])
                ]);
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to assign driver: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Membuat atau memperbarui data Surat Jalan (Waybill)
     */
    public function createWaybill(Order $order, Request $request)
    {
        if (auth()->user()->role !== 'admin') {
            return response()->json([
                'message' => 'Unauthorized. Admin access required.',
            ], 403);
        }

        $request->validate([
            'notes' => 'nullable|string',
        ]);

        $deliveryOrder = $order->deliveryOrder()->with('driver')->first();

        if (!$deliveryOrder) {
            return response()->json([
                'message' => 'No delivery assigned for this order.',
            ], 400);
        }

        $existingWaybill = Waybill::where('order_id', $order->id)->first();
        $waybillNumber = $existingWaybill ? $existingWaybill->waybill_number : 'WB-' . date('Ymd') . '-' . strtoupper(substr(uniqid(), -4));

        $waybill = Waybill::updateOrCreate(
            ['order_id' => $order->id],
            [
                'driver_id' => $deliveryOrder->driver_id,
                'waybill_number' => $waybillNumber,
                'notes' => $request->notes,
            ]
        );

        return response()->json([
            'message' => $existingWaybill ? 'Waybill updated successfully' : 'Waybill created successfully',
            'waybill' => $waybill->load(['order.orderItems.product', 'order.user', 'driver']),
        ]);
    }
}
<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController
{
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'role' => 'required|in:admin,mitra,driver',
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role,
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    public function me(Request $request)
    {
        return response()->json($request->user());
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeliveryOrder extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'driver_id',
        'status', // assigned, on_delivery, delivered
        'waybill_pdf',
    ];

    /**
     * Relasi ke Order Utama
     */
    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    /**
     * Relasi ke Driver (diarahkan ke tabel USERS)
     * Karena tabel drivers kosong, kita ambil data driver dari tabel users
     */
    public function driver()
    {
        // Hapus filter where('role', 'driver') di sini karena terkadang 
        // menyebabkan null saat eager loading jika role tidak ter-load sempurna
        return $this->belongsTo(User::class, 'driver_id');
    }

    /**
     * Relasi ke riwayat koordinat GPS (untuk tracking peta)
     */
    public function deliveryTracks()
    {
        return $this->hasMany(DeliveryTrack::class);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Models\Order;
use App\Models\DeliveryOrder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class DistanceController
{
    /**
     * Calculate distance and duration from warehouse to order destination
     * 
     * @param Order $order
     * @return \Illuminate\Http\JsonResponse
     */
    public function orderDistance(Order $order)
    {
        $user = auth()->user();

        // Check authorization
        if ($user->role === 'mitra' && $order->user_id !== $user->id) {
            return response()->json([
                'message' => 'Unauthorized. You do not have access to this order.',
            ], 403);
        }

        // Check if destination coordinates are set
        if (is_null($order->destination_lat) || is_null($order->destination_lng)) {
            return response()->json([
                'message' => 'Order destination coordinates not set.',
            ], 400);
        }

        // Get warehouse coordinates from config
        $originLat = config('services.warehouse.lat');
        $originLng = config('services.warehouse.lng');

        // Get destination coordinates from order
        $destLat = $order->destination_lat;
        $destLng = $order->destination_lng;

        try {
            // Call Google Directions API
            $response = Http::get('https://maps.googleapis.com/maps/api/directions/json', [
                'origin' => "{$originLat},{$originLng}",
                'destination' => "{$destLat},{$destLng}",
                'key' => config('services.google_maps.key'),
            ]);

            // Check if API call was successful
            if (!$response->successful()) {
                return response()->json([
                    'message' => 'Failed to fetch distance information.',
                ], 500);
            }

            $data = $response->json();

            // Check if Google API returned valid data
            if ($data['status'] !== 'OK' || empty($data['routes'])) {
                return response()->json([
                    'message' => 'Failed to fetch distance information.',
                    'error' => $data['status'] ?? 'Unknown error',
                ], 422);
            }

            // Extract distance and duration from first route
            $leg = $data['routes'][0]['legs'][0];

            return response()->json([
                'order_id' => $order->id,
                'origin' => [
                    'lat' => (float) $originLat,
                    'lng' => (float) $originLng,
                ],
                'destination' => [
                    'lat' => (float) $destLat,
                    'lng' => (float) $destLng,
                ],
                'distance_text' => $leg['distance']['text'],
                'distance_value' => $leg['distance']['value'],
                'duration_text' => $leg['duration']['text'],
                'duration_value' => $leg['duration']['value'],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to fetch distance information.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Calculate distance and duration from driver's last location to order destination
     * 
     * @param Order $order
     * @return \Illuminate\Http\JsonResponse
     */
    public function driverDistance(Order $order)
    {
        $user = auth()->user();

        // Check authorization
        if ($user->role === 'mitra' && $order->user_id !== $user->id) {
            return response()->json([
                'message' => 'Unauthorized. You do not have access to this order.',
            ], 403);
        }

        // Check if destination coordinates are set
        if (is_null($order->destination_lat) || is_null($order->destination_lng)) {
            return response()->json([
                'message' => 'Order destination coordinates not set.',
            ], 400);
        }

        // Find delivery order for this order
        $deliveryOrder = DeliveryOrder::where('order_id', $order->id)
            ->with('driver')
            ->first();

        if (!$deliveryOrder) {
            return response()->json([
                'message' => 'No driver location available for this order.',
            ], 400);
        }

        // Get last driver location from delivery tracks
        $lastTrack = $deliveryOrder->deliveryTracks()
            ->orderBy('recorded_at', 'desc')
            ->first();

        if (!$lastTrack) {
            return response()->json([
                'message' => 'No driver location available for this order.',
            ], 400);
        }

        // Get driver's last location
        $originLat = $lastTrack->lat;
        $originLng = $lastTrack->lng;

        // Get destination coordinates from order
        $destLat = $order->destination_lat;
        $destLng = $order->destination_lng;

        try {
            // Call Google Directions API
            $response = Http::get('https://maps.googleapis.com/maps/api/directions/json', [
                'origin' => "{$originLat},{$originLng}",
                'destination' => "{$destLat},{$destLng}",
                'key' => config('services.google_maps.key'),
            ]);

            // Check if API call was successful
            if (!$response->successful()) {
                return response()->json([
                    'message' => 'Failed to fetch distance information.',
                ], 500);
            }

            $data = $response->json();

            // Check if Google API returned valid data
            if ($data['status'] !== 'OK' || empty($data['routes'])) {
                return response()->json([
                    'message' => 'Failed to fetch distance information.',
                    'error' => $data['status'] ?? 'Unknown error',
                ], 422);
            }

            // Extract distance and duration from first route
            $leg = $data['routes'][0]['legs'][0];

            return response()->json([
                'order_id' => $order->id,
                'driver' => [
                    'id' => $deliveryOrder->driver->id,
                    'name' => $deliveryOrder->driver->name,
                ],
                'origin' => [
                    'lat' => (float) $originLat,
                    'lng' => (float) $originLng,
                ],
                'destination' => [
                    'lat' => (float) $destLat,
                    'lng' => (float) $destLng,
                ],
                'distance_text' => $leg['distance']['text'],
                'distance_value' => $leg['distance']['value'],
                'duration_text' => $leg['duration']['text'],
                'duration_value' => $leg['duration']['value'],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to fetch distance information.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

<?php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeliveryOrder;
use App\Models\DeliveryTrack;
use App\Services\GoogleDistanceService;
use Illuminate\Http\Request;

class DriverOrderController extends Controller
{
    /**
     * List order untuk Driver
     */
    public function index(Request $request)
    {
        if (auth()->user()->role !== 'driver') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }
        
        $perPage = $request->input('per_page', 15);
        
        $deliveryOrders = DeliveryOrder::where('driver_id', auth()->id())
            ->with(['order.orderItems.product', 'order.user', 'order.payment']) 
            ->latest()
            ->paginate($perPage);
        
        $ordersData = $deliveryOrders->getCollection()->map(function($deliveryOrder) {
            $order = $deliveryOrder->order;
            
            return [
                'id' => $order->id,
                'order_code' => $order->order_code,
                'user_id' => $order->user_id,
                'total_amount' => $order->total_amount,
                'status' => $order->status,
                'destination_address' => $order->destination_address,
                'destination_lat' => $order->destination_lat,
                'destination_lng' => $order->destination_lng,
                'distance_km' => $order->distance_km,
                'estimated_minutes' => $order->estimated_minutes,
                'created_at' => $order->created_at,
                'updated_at' => $order->updated_at,
                
                'user' => $order->user ? [
                    'id' => $order->user->id,
                    'name' => $order->user->name,
                    'email' => $order->user->email,
                    'phone' => $order->user->phone,
                ] : null,
                
                'order_items' => $order->orderItems ? $order->orderItems->map(function($item) {
                    return [
                        'id' => $item->id,
                        'product_id' => $item->product_id,
                        'quantity' => $item->quantity,
                        'price' => $item->price,
                        'subtotal' => $item->subtotal,
                        'product' => $item->product ? [
                            'id' => $item->product->id,
                            'name' => $item->product->name,
                            'price' => $item->product->price,
                            'category' => $item->product->category,
                        ] : null,
                    ];
                }) : [],
                
                'payment' => $order->payment ? [
                    'id' => $order->payment->id,
                    'status' => $order->payment->status,
                    'payment_method' => $order->payment->payment_method,
                    'amount' => $order->payment->amount,
                ] : null,
                
                'delivery_order' => [
                    'id' => $deliveryOrder->id,
                    'driver_id' => $deliveryOrder->driver_id,
                    'status' => $deliveryOrder->status,
                    'assigned_at' => $deliveryOrder->assigned_at,
                    'created_at' => $deliveryOrder->created_at,
                ],
            ];
        });
        
        return response()->json([
            'success' => true,
            'data' => [
                'current_page' => $deliveryOrders->currentPage(),
                'data' => $ordersData,
                'last_page' => $deliveryOrders->lastPage(),
                'total' => $deliveryOrders->total(),
                'per_page' => $deliveryOrders->perPage(),
                'from' => $deliveryOrders->firstItem(),
                'to' => $deliveryOrders->lastItem(),
            ]
        ]);
    }

    /**
     * ✅ FITUR BARU: Update Status & Hitung Jarak Otomatis
     * Ini yang membuat status berubah ke 'on_delivery' dan memicu GPS di Flutter
     */
public function updateStatus(Request $request, $id)
{
    $request->validate([
        'status' => 'required|in:picked_up,on_delivery,delivered'
    ]);

    try {
        // Cari delivery_order. Kita coba cari lewat ID delivery_order dulu, 
        // kalau gagal kita cari lewat order_id (supaya cocok dengan yang dikirim Flutter)
        $delivery = \App\Models\DeliveryOrder::where('id', $id)
                    ->orWhere('order_id', $id)
                    ->first();

        if (!$delivery) {
            return response()->json([
                'success' => false, 
                'message' => 'Data pengiriman tidak ditemukan untuk ID: ' . $id
            ], 404);
        }

        $order = $delivery->order;

        // 1. Hitung Jarak Otomatis jika status 'on_delivery'
        if ($request->status == 'on_delivery' && $order) {
            $googleService = new \App\Services\GoogleDistanceService();
            $distData = $googleService->getDistanceAndDuration($order->destination_lat, $order->destination_lng);
            if ($distData) {
                $order->update([
                    'distance_km' => $distData['distance_km'],
                    'estimated_minutes' => $distData['duration_min']
                ]);
            }
        }

        // 2. UPDATE STATUS DI KEDUA TABEL (PENTING!)
        $delivery->update(['status' => $request->status]);
        
        if ($order) {
            $order->update(['status' => $request->status]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Status berhasil diperbarui ke ' . $request->status,
            'current_status' => $request->status
        ]);

    } catch (\Exception $e) {
        \Log::error("Update Status Error ID $id: " . $e->getMessage());
        return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
    }
}

    public function track(Request $request, $orderId)
    {
        // Cari delivery order berdasarkan order_id
        $deliveryOrder = DeliveryOrder::where('order_id', $orderId)->firstOrFail();

        if ($deliveryOrder->driver_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }
        
        $request->validate([
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
        ]);
        
        $track = DeliveryTrack::create([
            'delivery_order_id' => $deliveryOrder->id,
            'lat' => $request->lat,
            'lng' => $request->lng,
            'recorded_at' => now(),
        ]);
        
        return response()->json([
            'success' => true,
            'message' => 'Location recorded successfully',
            'track' => $track,
        ]);
    }
    
    public function updateAvailability(Request $request)
    {
        $request->validate([
            'status' => 'required|in:available,busy,offline'
        ]);
        
        auth()->user()->update(['availability_status' => $request->status]);
        
        return response()->json([
            'success' => true,
            'message' => 'Availability status updated successfully',
            'status' => $request->status
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Waybill;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 15);
        $status = $request->input('status');
        $dateFrom = $request->input('date_from');
        $dateTo = $request->input('date_to');
        
        $query = Order::where('user_id', $request->user()->id)
            ->with(['orderItems.product', 'deliveryOrder', 'payment']);
        
        // Apply filters
        if ($status) {
            $query->where('status', $status);
        }
        
        if ($dateFrom) {
            $query->whereDate('created_at', '>=', $dateFrom);
        }
        
        if ($dateTo) {
            $query->whereDate('created_at', '<=', $dateTo);
        }
        
        $orders = $query->latest()->paginate($perPage);

        return response()->json($orders);
    }

/**
     * Simpan order baru
     */
    public function store(Request $request)
    {
        if (is_string($request->items)) {
            $request->merge([
                'items' => json_decode($request->items, true)
            ]);
        }

        // Validasi sekarang akan berjalan lancar karena 'items' sudah pasti berbentuk Array
        $request->validate([
            'destination_address' => 'required|string',
            'destination_lat' => 'required|numeric', 
            'destination_lng' => 'required|numeric',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
        ]);

        return DB::transaction(function () use ($request) {
            // ... (kode sisa kakak ke bawah tetap sama)
            $order = Order::create([
                'user_id' => $request->user()->id,
                'order_code' => 'ORD-' . strtoupper(uniqid()),
                'destination_address' => $request->destination_address,
                'destination_lat' => $request->destination_lat,
                'destination_lng' => $request->destination_lng,
                'total_amount' => 0,
            ]);

            $totalAmount = 0;

            foreach ($request->items as $item) {
                $product = Product::findOrFail($item['product_id']);
                $subtotal = $product->price * $item['quantity'];

                OrderItem::create([
                    'order_id' => $order->id,
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'price' => $product->price,
                    'subtotal' => $subtotal,
                ]);

                $totalAmount += $subtotal;
            }

            $order->update(['total_amount' => $totalAmount]);

            return response()->json($order->load('orderItems.product'), 201);
        });
    }

    /**
     * Detail satu order
     */
    public function show(Order $order)
    {
        if ($order->user_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        return response()->json(
            $order->load(['orderItems.product', 'deliveryOrder.driver', 'payment', 'waybill'])
        );
    }

    /**
     * Cancel order with refund logic
     */
    public function cancel(Order $order)
    {
        if ($order->user_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if (in_array($order->status, ['on_delivery', 'completed'])) {
            return response()->json([
                'message' => 'Cannot cancel order that is already on delivery or completed',
            ], 400);
        }

        return DB::transaction(function () use ($order) {
            // 1. Check if payment exists and is paid
            $payment = $order->payment;
            
            if ($payment && $payment->status === 'paid') {
                // 2. Process refund via Tripay
                $tripayService = app(\App\Services\TripayService::class);
                $refundResult = $tripayService->requestRefund($payment);
                
                if ($refundResult['success']) {
                    $payment->update([
                        'status' => 'refunded',
                        'refunded_at' => now()
                    ]);
                }
            }
            
            // 3. Return stock to products
            foreach ($order->orderItems as $item) {
                $product = $item->product;
                $product->increment('stock', $item->quantity);
            }
            
            // 4. Cancel delivery if exists
            if ($order->deliveryOrder) {
                $order->deliveryOrder->update(['status' => 'cancelled']);
            }
            
            // 5. Update order status
            $order->update([
                'status' => 'cancelled',
                'cancelled_at' => now()
            ]);
            
            // 6. Log activity
            \App\Services\ActivityLogger::logOrderCancelled($order, 'Cancelled by user');

            return response()->json([
                'message' => 'Order cancelled successfully' . ($payment && $payment->status === 'refunded' ? ' and refund processed' : ''),
                'order' => $order->fresh()->load(['orderItems.product', 'deliveryOrder', 'payment']),
            ]);
        });
    }

 /**
     * Tracking lokasi driver
     */
  public function tracking(Order $order)
{
    // Ambil data delivery, tapi jangan error kalau kosong
    $deliveryOrder = $order->deliveryOrder()->with('driver')->first();

    $response = [
        'order_status' => $this->mapOrderStatus($order->status),
        'driver_location' => null,
        'destination_location' => [
            'latitude' => (float) ($order->destination_lat ?? 0),
            'longitude' => (float) ($order->destination_lng ?? 0),
        ],
        'distance_km' => (float) ($order->distance_km ?? 0),
        'estimated_minutes' => $order->estimated_minutes ?? 0,
        'driver' => null,
    ];

    // Cek apakah deliveryOrder dan driver benar-benar ADA sebelum diakses
    if ($deliveryOrder && $deliveryOrder->driver) {
        $lastLocation = $deliveryOrder->deliveryTracks()
            ->orderBy('recorded_at', 'desc')
            ->first();

        if ($lastLocation) {
            $response['driver_location'] = [
                'latitude' => (float) $lastLocation->lat,
                'longitude' => (float) $lastLocation->lng,
            ];
        }

        $response['driver'] = [
            'name' => $deliveryOrder->driver->name,
            'phone' => (string) ($deliveryOrder->driver->phone ?? '-'),
        ];
    }

    return response()->json($response);
}

    /**
     * Helper status mapping (Gunakan Versi Indonesia agar bagus di UI Flutter)
     */
     private function mapOrderStatus($status)
    {
        $statusMap = [
            'pending' => 'pending',
            'confirmed' => 'confirmed',
            'on_delivery' => 'on_the_way',
            'completed' => 'delivered',
            'cancelled' => 'cancelled',
        ];

        return $statusMap[$status] ?? $status;
    }
    /**
     * Tampilkan Surat Jalan (Waybill)
     */
    public function showWaybill(Order $order)
    {
        $user = auth()->user();

        if ($order->user_id !== $user->id && $user->role !== 'admin') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $waybill = Waybill::where('order_id', $order->id)
            ->with(['order.orderItems.product', 'order.user', 'driver'])
            ->first();

        if (!$waybill) {
            return response()->json(['message' => 'Waybill not found.'], 404);
        }

        return response()->json([
            'waybill' => $waybill,
            'order' => [
                'id' => $order->id,
                'order_code' => $order->order_code,
                'status' => $order->status,
                'total_amount' => $order->total_amount,
                'destination_address' => $order->destination_address,
            ],
            'items' => $waybill->order->orderItems->map(function ($item) {
                return [
                    'product_name' => $item->product->name,
                    'quantity' => $item->quantity,
                    'price' => $item->price,
                    'subtotal' => $item->subtotal,
                ];
            }),
            'driver' => $waybill->driver ? [
                'id' => $waybill->driver->id,
                'name' => $waybill->driver->name,
                'email' => $waybill->driver->email,
            ] : null,
            'mitra' => [
                'id' => $waybill->order->user->id,
                'name' => $waybill->order->user->name,
                'email' => $waybill->order->user->email,
            ],
        ]);
    }

    /**
     * Upload foto terkait order (BARU)
     */
    public function uploadPhoto(Request $request, Order $order)
    {
        $user = $request->user();

        if ($order->user_id !== $user->id && $user->role !== 'admin') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $request->validate([
            'photo' => 'required|image|mimes:jpeg,png,jpg|max:5120', // Max 5MB
            'description' => 'nullable|string|max:255',
        ]);

        // Optimize and save image
        $image = $request->file('photo');
        $filename = 'order_' . $order->id . '_' . time() . '_' . uniqid() . '.jpg';
        
        $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());
        $img = $manager->read($image->getPathname());
        $img->scale(width: 1200); // Larger size for order photos
        $encoded = $img->toJpeg(80);
        
        $path = 'order_photos/' . $filename;
        Storage::disk('public')->put($path, (string) $encoded);
        
        $url = Storage::disk('public')->url($path);

        return response()->json([
            'message' => 'Photo uploaded successfully',
            'order_id' => $order->id,
            'url' => $url,
            'path' => $path
        ], 201);
    }

    /**
     * List semua foto order (BARU)
     */
    public function photos(Order $order)
    {
        $user = auth()->user();

        if ($order->user_id !== $user->id && $user->role !== 'admin') {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $directory = 'order_photos';
        $files = Storage::disk('public')->files($directory);

        $orderPhotos = collect($files)->filter(function ($file) use ($order) {
            return str_contains($file, 'order_' . $order->id . '_');
        })->map(function ($file) {
            return [
                'filename' => basename($file),
                'url' => Storage::disk('public')->url($file),
                'size' => Storage::disk('public')->size($file),
            ];
        })->values(); // Reset keys array agar rapi di JSON

        return response()->json([
            'order_id' => $order->id,
            'photos' => $orderPhotos,
        ]);
    }
    /**
 * Endpoint untuk Driver mengupdate lokasi GPS
 */
public function updateDriverLocation(Request $request, $orderId)
{
    // 1. Validasi Input
    $request->validate([
        'lat' => 'required|numeric',
        'lng' => 'required|numeric',
    ]);

    // 2. Cari DeliveryOrder yang terhubung dengan Order ini
    $deliveryOrder = \App\Models\DeliveryOrder::where('order_id', $orderId)->first();

    if (!$deliveryOrder) {
        return response()->json([
            'success' => false, 
            'message' => 'Data pengiriman tidak ditemukan'
        ], 404);
    }

    // 3. Simpan koordinat baru ke tabel delivery_tracks
    $track = \App\Models\DeliveryTrack::create([
        'delivery_order_id' => $deliveryOrder->id,
        'lat' => $request->lat,
        'lng' => $request->lng,
        'recorded_at' => now(), 
    ]);

    return response()->json([
        'success' => true,
        'message' => 'Lokasi berhasil diperbarui',
        'data' => [
            'lat' => $track->lat,
            'lng' => $track->lng,
            'time' => $track->recorded_at->format('H:i:s')
        ]
    ]);
}
}


<?php

namespace App\Http\Controllers\Api;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\Product;
use App\Services\TripayService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController
{
    protected $tripayService;

    public function __construct(TripayService $tripayService)
    {
        $this->tripayService = $tripayService;
    }

    /**
     * Alur Baru: Membuat Order dan Transaksi Pembayaran Sekaligus
     * Dipanggil dari CheckoutPaymentScreen di Flutter
     */
    public function initiateCheckoutPayment(Request $request)
    {
        $request->validate([
            'destination_address' => 'required|string',
            'destination_lat' => 'nullable|numeric',
            'destination_lng' => 'nullable|numeric',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'payment_method' => 'required|string',
        ]);

        return DB::transaction(function () use ($request) {
            $totalAmount = 0;
            $orderItemsData = [];

            // 1. Validasi Stok dan Hitung Total
            foreach ($request->items as $item) {
                $product = Product::lockForUpdate()->findOrFail($item['product_id']);
                
                if ($product->stock < $item['quantity']) {
                    throw new \Exception("Stok produk {$product->name} tidak mencukupi.");
                }

                $subtotal = $product->price * $item['quantity'];
                $totalAmount += $subtotal;

                $orderItemsData[] = [
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'price' => $product->price,
                    'subtotal' => $subtotal,
                ];

                // Kurangi stok (Reserve stock)
                $product->decrement('stock', $item['quantity']);
            }

            // 2. Buat Order (Status awal: pending_payment)
            $order = Order::create([
                'user_id' => auth()->id(),
                'order_code' => 'ORD-' . strtoupper(uniqid()),
                'destination_address' => $request->destination_address,
                'destination_lat' => $request->destination_lat,
                'destination_lng' => $request->destination_lng,
                'total_amount' => $totalAmount,
                'status' => 'pending_payment', // Status baru sesuai rencana
            ]);

            // 3. Simpan Item Order
            foreach ($orderItemsData as $itemData) {
                $order->orderItems()->create($itemData);
            }

            // 4. Inisiasi Transaksi Tripay via Service
            // Pastikan TripayService mendukung parameter kedua (payment_method)
            $tripayResult = $this->tripayService->createTransaction($order, $request->payment_method);

            if (!$tripayResult['success']) {
                throw new \Exception($tripayResult['message'] ?? 'Gagal membuat transaksi di Tripay');
            }

            return response()->json([
                'success' => true,
                'message' => 'Order created, waiting for payment',
                'order' => $order->load('orderItems.product'),
                'payment' => $tripayResult['payment'],
                'checkout_url' => $tripayResult['checkout_url'],
            ], 201);
        });
    }

    /**
     * Method lama untuk Bayar Ulang jika transaksi sebelumnya expired/belum dibuat
     */
    public function pay(Order $order, Request $request)
    {
        if ($order->user_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($order->payment && $order->payment->status === 'paid') {
            return response()->json(['message' => 'Order already paid'], 400);
        }

        $paymentMethod = $request->payment_method ?? $order->payment->payment_method ?? 'QRIS';
        $result = $this->tripayService->createTransaction($order, $paymentMethod);

        if ($result['success']) {
            return response()->json([
                'message' => 'Payment created successfully',
                'payment' => $result['payment'],
                'checkout_url' => $result['checkout_url'],
            ]);
        }

        return response()->json(['message' => $result['message']], 400);
    }

    /**
     * Handler Callback dari Tripay
     */
public function callback(Request $request)
{
    $json = $request->getContent();
    $data = json_decode($json);

    if (!$data) return response()->json(['message' => 'Data Kosong'], 400);

    // Cari payment berdasarkan merchant_ref (ORD-xxx)
    $payment = \App\Models\Payment::where('merchant_ref', $data->merchant_ref)->first();

    if (!$payment) {
        \Log::error("Callback Gagal: Ref {$data->merchant_ref} tidak ada di DB.");
        return response()->json(['message' => 'Payment not found'], 404);
    }

    if ($data->status === 'PAID') {
        \DB::transaction(function () use ($payment) {
            // 1. Update Payment jadi PAID
            $payment->update([
                'status' => 'paid',
                'paid_at' => now(),
            ]);

            // 2. Update Order jadi PENDING (untuk diproses admin)
            if ($payment->order) {
                $payment->order->update(['status' => 'pending']);
            }
        });

        \Log::info("DATABASE BERHASIL UPDATE: " . $data->merchant_ref);
        return response()->json(['success' => true]);
    }

    return response()->json(['message' => 'Status is ' . $data->status]);
}
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver;

class ProductController extends Controller
{
    const CATEGORIES = [
        'Premium', 'Standard', 'Grade A', 'Grade B', 'Grade C', 'Organik', 'Non-Organik',
    ];

    /**
     * Helper untuk membuat URL Full secara konsisten
     */
    private function getFullUrl($path)
    {
        if (!$path) return null;
        // asset() lebih aman daripada Storage::url() jika APP_URL di .env sudah benar
        return asset('storage/' . $path);
    }

    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 15);
        $products = Product::latest()->paginate($perPage);
        
        $products->getCollection()->transform(function ($product) {
            // Kita simpan path aslinya di field lain jika butuh, 
            // tapi timpa field images dengan URL lengkap untuk Flutter
            if ($product->images) {
                $product->images = $this->getFullUrl($product->images);
            }
            return $product;
        });
        
        return response()->json($products);
    }

    public function store(Request $request)
    {
        $request->validate([
            'name'        => 'required|string|max:255',
            'description' => 'nullable|string',
            'price'       => 'required|numeric|min:0',
            'stock'       => 'required|integer|min:0',
            'category'    => 'required|string|in:' . implode(',', self::CATEGORIES),
            'image_file'  => 'nullable|image|mimes:jpeg,png,jpg|max:5120', 
        ]);

        $data = $request->only(['name', 'description', 'price', 'stock', 'category']);

        if ($request->hasFile('image_file')) {
            $image = $request->file('image_file');
            $filename = 'product_' . time() . '_' . uniqid() . '.jpg';
            
            // Proses Gambar
            $manager = new ImageManager(new Driver());
            $img = $manager->read($image->getPathname());
            $img->scale(width: 800); 
            $encoded = $img->toJpeg(75);
            
            $path = 'products/' . $filename;
            Storage::disk('public')->put($path, (string) $encoded);
            
            $data['images'] = $path;
        }

        $product = Product::create($data);
        
        // Return dengan URL Lengkap
        $product->images = $this->getFullUrl($product->images);

        return response()->json([
            'message' => 'Produk berhasil ditambahkan',
            'product' => $product
        ], 201);
    }

    public function show(Product $product)
    {
        $product->images = $this->getFullUrl($product->images);
        return response()->json($product);
    }

 public function update(Request $request, Product $product)
{
    // Debugging: Buka ini kalau mau cek data apa yang masuk ke Laravel
    // return response()->json($request->all());

    $request->validate([
        'name'        => 'sometimes|required|string|max:255',
        'description' => 'nullable|string',
        'price'       => 'sometimes|required|numeric|min:0',
        'stock'       => 'sometimes|required|integer|min:0',
        'category'    => 'sometimes|required|string|in:' . implode(',', self::CATEGORIES),
        'image_file'  => 'nullable|image|mimes:jpeg,png,jpg|max:5120',
    ]);

    $data = $request->only(['name', 'description', 'price', 'stock', 'category']);

    if ($request->hasFile('image_file')) {
        // 1. Ambil path asli dari DB (pastikan bukan URL http://...)
        $oldImagePath = $product->getRawOriginal('images');

        // 2. Hapus hanya jika path ada di DB dan file fisiknya ada
        if (!empty($oldImagePath) && Storage::disk('public')->exists($oldImagePath)) {
            Storage::disk('public')->delete($oldImagePath);
        }
        
        // 3. Proses Upload Baru
        $image = $request->file('image_file');
        $filename = 'product_' . time() . '_' . uniqid() . '.jpg';
        
        $manager = new ImageManager(new Driver());
        $img = $manager->read($image->getPathname());
        $img->scale(width: 800);
        $encoded = $img->toJpeg(75);
        
        $path = 'products/' . $filename;
        Storage::disk('public')->put($path, (string) $encoded);
        
        $data['images'] = $path;
    }

    $product->update($data);

    // Kirim response balik dengan URL Lengkap
    $product->images = $this->getFullUrl($product->images);

    return response()->json([
        'message' => 'Produk berhasil diperbarui',
        'product' => $product
    ]);
}

    public function destroy(Product $product)
    {
        // Gunakan getRawOriginal agar tidak terganggu accessor jika ada
        $imagePath = $product->getRawOriginal('images') ?? $product->images;
        
        if ($imagePath) {
            Storage::disk('public')->delete($imagePath);
        }
        
        $product->delete();
        return response()->json(['message' => 'Produk berhasil dihapus']);
    }

    public function getCategories()
    {
        return response()->json(['categories' => self::CATEGORIES]);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver;

class ProfileController extends Controller
{
    /**
     * Get current user profile
     */
    public function show()
    {
        $user = auth()->user();
        
        // Add full URL for profile photo
        if ($user->profile_photo && !str_starts_with($user->profile_photo, 'http')) {
            $user->profile_photo = Storage::disk('public')->url($user->profile_photo);
        }
        
        return response()->json($user);
    }

    /**
     * Update user profile
     */
    public function update(Request $request)
    {
        $user = auth()->user();
        
        $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'email' => 'sometimes|required|email|unique:users,email,' . $user->id,
            'phone' => 'sometimes|nullable|string|max:20',
            'address' => 'sometimes|nullable|string',
        ]);
        
        $user->update($request->only(['name', 'email', 'phone', 'address']));
        
        return response()->json([
            'message' => 'Profile updated successfully',
            'user' => $user
        ]);
    }

    /**
     * Change password
     */
    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8|confirmed',
        ]);
        
        $user = auth()->user();
        
        // Verify current password
        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'message' => 'Current password is incorrect'
            ], 400);
        }
        
        // Update password
        $user->update([
            'password' => Hash::make($request->new_password)
        ]);
        
        return response()->json([
            'message' => 'Password changed successfully'
        ]);
    }

    /**
     * Upload profile photo with optimization
     */
    public function uploadPhoto(Request $request)
    {
        $request->validate([
            'photo' => 'required|image|mimes:jpeg,png,jpg|max:5120', // Max 5MB
        ]);
        
        $user = auth()->user();
        
        // Delete old photo if exists
        if ($user->profile_photo) {
            Storage::disk('public')->delete($user->profile_photo);
        }
        
        // Optimize and save image
        $image = $request->file('photo');
        $filename = 'profile_' . $user->id . '_' . time() . '.jpg';
        
        // Create image manager with GD driver
        $manager = new ImageManager(new Driver());
        
        // Read and resize image
        $img = $manager->read($image->getPathname());
        $img->scale(width: 400); // Resize to max width 400px, maintain aspect ratio
        
        // Encode to JPEG with 80% quality
        $encoded = $img->toJpeg(80);
        
        // Save to storage
        $path = 'profiles/' . $filename;
        Storage::disk('public')->put($path, (string) $encoded);
        
        // Update user
        $user->update(['profile_photo' => $path]);
        
        return response()->json([
            'message' => 'Profile photo uploaded successfully',
            'photo_url' => Storage::disk('public')->url($path)
        ]);
    }
}


<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Update FCM token for push notifications
     */
    public function updateFcmToken(Request $request)
    {
        $request->validate([
            'fcm_token' => 'required|string'
        ]);
        
        auth()->user()->update([
            'fcm_token' => $request->fcm_token
        ]);
        
        return response()->json([
            'message' => 'FCM token updated successfully'
        ]);
    }
}


<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Waybill;
use App\Models\User;
use Illuminate\Http\Request;
use Barryvdh\DomPDF\Facade\Pdf;

class WaybillController extends Controller
{
 public function downloadWaybillPdf(Order $order)
{
    $waybill = $order->waybill; // Asumsi relasi hasOne di model Order

    if (!$waybill || !$waybill->pdf_path) {
        return response()->json(['message' => 'PDF tidak ditemukan'], 404);
    }

    $path = storage_path('app/public/waybills/' . $waybill->pdf_path);

    if (!file_exists($path)) {
        return response()->json(['message' => 'File fisik tidak ditemukan'], 404);
    }

    return response()->file($path, [
        'Content-Type' => 'application/pdf',
        'Content-Disposition' => 'inline; filename="waybill.pdf"'
    ]);
}
}

<?php

namespace App\Http\Controllers;

use Illuminate\Routing\Controller as BaseController;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;

abstract class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;
}


Middleware:
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
   public function handle(Request $request, Closure $next, string $role): Response
{
    if ($request->user() && $request->user()->role === $role) {
        return $next($request);
    }
    return response()->json([
        'message' => "Unauthorized. Only users with role: {$role} can access this resource."
    ], 403);
}
}


Models:
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ActivityLog extends Model
{
    protected $fillable = [
        'user_id',
        'action',
        'model',
        'model_id',
        'details',
    ];
    
    protected $casts = [
        'details' => 'array',
    ];
    
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeliveryOrder extends Model
{
    protected $fillable = [
        'order_id',
        'driver_id',
        'status',
        'assigned_at',
        'completed_at',
    ];

    protected $casts = [
        'assigned_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function deliveryTracks()
    {
        return $this->hasMany(DeliveryTrack::class);
    }
}


<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeliveryTrack extends Model
{
    protected $fillable = [
        'delivery_order_id',
        'lat',
        'lng',
        'recorded_at',
    ];

    protected $casts = [
        'lat' => 'decimal:8',
        'lng' => 'decimal:8',
        'recorded_at' => 'datetime',
    ];

    // Relasi balik ke DeliveryOrder
    public function deliveryOrder()
    {
        return $this->belongsTo(DeliveryOrder::class);
    }
}


<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    protected $fillable = [
        'user_id',
        'order_code',
        'total_amount',
        'status',
        'destination_address',
        'destination_lat',
        'destination_lng',
        'distance_km',
        'estimated_minutes',
        'cancelled_at',
    ];

 protected $casts = [
    'total_amount' => 'double',    
    'destination_lat' => 'double', 
    'destination_lng' => 'double', 
    'distance_km' => 'double',      
    'estimated_minutes' => 'integer',
    'cancelled_at' => 'datetime',
];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function deliveryOrder()
    {
        return $this->hasOne(DeliveryOrder::class, 'order_id');
    }

    public function payment()
    {
        return $this->hasOne(Payment::class);
    }

    public function waybill()
    {
        return $this->hasOne(Waybill::class);
    }
}


<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItem extends Model
{
    protected $fillable = [
        'order_id',
        'product_id',
        'quantity',
        'price',
        'subtotal',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'subtotal' => 'decimal:2',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    protected $fillable = [
        'order_id',
        'reference',
        'merchant_ref',
        'amount',
        'payment_method',
        'status',
        'paid_at',
        'expired_at',
        'raw_response',
        'refunded_at',
    ];

    protected $casts = [
        'amount' => 'double',
        'paid_at' => 'datetime',
        'expired_at' => 'datetime',
        'raw_response' => 'array',
        'refunded_at' => 'datetime',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = [
        'name',
        'description',
        'price',
        'stock',
        'category',
        'images',
    ];

    protected $casts = [
        'price' => 'double',
        'stock' => 'integer',
    ];

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasFactory, Notifiable, HasApiTokens;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'role',
        'address',
        'profile_photo',
        'fcm_token',
        'availability_status',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function orders()
    {
        return $this->hasMany(Order::class);
    }

    public function deliveryOrders()
    {
        return $this->hasMany(DeliveryOrder::class, 'driver_id');
    }

    public function waybills()
    {
        return $this->hasMany(Waybill::class, 'driver_id');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Waybill extends Model
{
    protected $fillable = [
        'order_id',
        'driver_id',
        'waybill_number',
        'notes',
        'pdf_path',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
}

Providers:
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Log slow queries (queries taking more than 1 second)
        \Illuminate\Support\Facades\DB::listen(function ($query) {
            if ($query->time > 1000) { // More than 1 second
                \Illuminate\Support\Facades\Log::warning('Slow Query Detected', [
                    'sql' => $query->sql,
                    'bindings' => $query->bindings,
                    'time' => $query->time . 'ms'
                ]);
            }
        });
    }
}


Services:

<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GoogleDistanceService
{
    /**
     * Mengambil jarak dan durasi dari Kantor ke Lokasi Tujuan
     */
    public function getDistanceAndDuration($destLat, $destLng)
    {
        $apiKey = env('GOOGLE_MAPS_API_KEY');
        $originLat = env('WAREHOUSE_LAT');
        $originLng = env('WAREHOUSE_LNG');

        // Proteksi jika data di .env belum lengkap
        if (!$apiKey || !$originLat || !$originLng) {
            Log::error("Google Maps API: Data .env tidak lengkap (API Key/Lat/Lng Kantor)");
            return null;
        }

        try {
            $response = Http::get("https://maps.googleapis.com/maps/api/distancematrix/json", [
                'origins' => "$originLat,$originLng",
                'destinations' => "$destLat,$destLng",
                'key' => $apiKey,
                'mode' => 'driving',
            ]);

            if ($response->successful() && $response['status'] == 'OK') {
                $element = $response['rows'][0]['elements'][0];
                
                if ($element['status'] == 'OK') {
                    return [
                        'distance_km' => round($element['distance']['value'] / 1000, 2),
                        'duration_min' => round($element['duration']['value'] / 60),
                    ];
                } else {
                    Log::warning("Google API Element Error: " . $element['status']);
                }
            } else {
                Log::error("Google API Response Error: " . $response['status']);
            }
        } catch (\Exception $e) {
            Log::error("Gagal menghubungi Google API: " . $e->getMessage());
        }

        return null;
    }
}

<?php

namespace App\Services;

use App\Models\ActivityLog;

class ActivityLogger
{
    /**
     * Log an activity
     */
    public static function log($action, $model = null, $modelId = null, $details = [])
    {
        return ActivityLog::create([
            'user_id' => auth()->id(),
            'action' => $action,
            'model' => $model,
            'model_id' => $modelId,
            'details' => $details,
        ]);
    }
    
    /**
     * Log order creation
     */
    public static function logOrderCreated($order)
    {
        return self::log('order.created', 'Order', $order->id, [
            'order_code' => $order->order_code,
            'total_amount' => $order->total_amount,
        ]);
    }
    
    /**
     * Log order approval
     */
    public static function logOrderApproved($order)
    {
        return self::log('order.approved', 'Order', $order->id, [
            'order_code' => $order->order_code,
        ]);
    }
    
    /**
     * Log driver assignment
     */
    public static function logDriverAssigned($order, $driver)
    {
        return self::log('order.driver_assigned', 'Order', $order->id, [
            'order_code' => $order->order_code,
            'driver_id' => $driver->id,
            'driver_name' => $driver->name,
        ]);
    }
    
    /**
     * Log order cancellation
     */
    public static function logOrderCancelled($order, $reason = null)
    {
        return self::log('order.cancelled', 'Order', $order->id, [
            'order_code' => $order->order_code,
            'reason' => $reason,
        ]);
    }
}

<?php

namespace App\Services;

use App\Models\User;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

class NotificationService
{
    protected $messaging;
    
   public function __construct()
{
    try {
        if (config('firebase.credentials')) {
            $factory = (new Factory)->withServiceAccount(
                base_path(config('firebase.credentials'))
            );
            $this->messaging = $factory->createMessaging();
        }
    } catch (\Throwable $e) {
        \Log::error('Firebase init failed: ' . $e->getMessage());
        $this->messaging = null;
    }
}

    
    /**
     * Send notification to a specific user
     */
    public function sendToUser($userId, $title, $body, $data = [])
    {
        if (!$this->messaging) {
            \Log::warning('Firebase not configured, skipping notification');
            return false;
        }
        
        $user = User::find($userId);
        
        if (!$user || !$user->fcm_token) {
            return false;
        }
        
        try {
            $message = CloudMessage::withTarget('token', $user->fcm_token)
                ->withNotification(Notification::create($title, $body))
                ->withData($data);
                
            $this->messaging->send($message);
            return true;
        } catch (\Exception $e) {
            \Log::error('FCM notification failed: ' . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Send order notification to mitra
     */
    public function sendOrderNotification($order, $title, $body, $type)
    {
        return $this->sendToUser(
            $order->user_id,
            $title,
            $body,
            [
                'type' => $type,
                'order_id' => $order->id,
                'order_code' => $order->order_code
            ]
        );
    }
    
    /**
     * Send driver notification
     */
    public function sendDriverNotification($driverId, $title, $body, $data = [])
    {
        return $this->sendToUser($driverId, $title, $body, array_merge($data, ['type' => 'driver_notification']));
    }
}

<?php

namespace App\Services;

use App\Models\Order;
use App\Models\Payment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TripayService
{
    protected $merchantCode;
    protected $apiKey;
    protected $privateKey;
    protected $apiUrl;

    public function __construct()
    {
        $this->merchantCode = config('tripay.merchant_code');
        $this->apiKey = config('tripay.api_key');
        $this->privateKey = config('tripay.private_key');
        $this->apiUrl = config('tripay.api_url');
    }

    /**
     * Perbaikan: Menambahkan parameter $method agar tidak kaku (BRIVA)
     */
    public function createTransaction(Order $order, string $method = 'QRIS')
    {
        // Gunakan order_code dari database agar sinkron saat callback
        $merchantRef = $order->order_code; 
        $amount = (int) $order->total_amount;

        $signature = hash_hmac('sha256', $this->merchantCode . $merchantRef . $amount, $this->privateKey);

        $payload = [
            'method'         => $method, // Dinamis sesuai pilihan user
            'merchant_ref'   => $merchantRef,
            'amount'         => $amount,
            'customer_name'  => $order->user->name,
            'customer_email' => $order->user->email,
            'customer_phone' => $order->user->phone ?? '08123456789', // Default jika null
            'order_items'    => $order->orderItems->map(function ($item) {
                return [
                    'name'     => $item->product->name,
                    'price'    => (int) $item->price,
                    'quantity' => $item->quantity,
                ];
            })->toArray(),
            'callback_url' => 'https://unpensionable-zander-unmotioned.ngrok-free.dev/api/payment/tripay/callback', // Pastikan route ini benar
            'return_url'     => url('/'),
            'signature'      => $signature,
        ];

        $response = Http::withoutVerifying()
            ->withHeaders([
                'Authorization' => 'Bearer ' . $this->apiKey,
            ])
            ->post($this->apiUrl . '/transaction/create', $payload);

        $data = $response->json();

        if ($response->successful() && isset($data['success']) && $data['success']) {
            // Update atau Create data payment
            $payment = Payment::updateOrCreate(
                ['order_id' => $order->id],
                [
                    'reference'    => $data['data']['reference'],
                    'merchant_ref' => $merchantRef,
                    'amount'       => $amount,
                    'payment_method' => $method,
                    'status'       => 'unpaid',
                    'expired_at'   => now()->addHours(24),
                    'raw_response' => $data,
                ]
            );

            return [
                'success'              => true,
                'payment'              => $payment,
                'checkout_url'         => $data['data']['checkout_url'] ?? null,
                'payment_instructions' => $data['data'],
            ];
        }

        return [
            'success' => false,
            'message' => $data['message'] ?? 'Failed to create transaction',
        ];
    }

    /**
     * Perbaikan: Tambah bypass untuk testing lokal
     */
    public function verifyCallback($callbackSignature, $merchantRef, $amount)
    {
        // Bypass jika di environment local agar Postman lancar
        if (config('app.env') === 'local') {
            return true;
        }

        $localSignature = hash_hmac('sha256', $merchantRef . $amount, $this->privateKey);
        return $callbackSignature === $localSignature;
    }
    
    /**
     * Request refund for a payment
     */
    public function requestRefund(Payment $payment)
    {
        try {
            // Check if payment is eligible for refund
            if ($payment->status !== 'paid') {
                return [
                    'success' => false,
                    'message' => 'Payment is not in paid status'
                ];
            }
            
            // Tripay refund API endpoint
            $endpoint = $this->apiUrl . '/transaction/refund';
            
            $payload = [
                'reference' => $payment->reference,
                'reason' => 'Order cancelled by customer'
            ];
            
            $signature = hash_hmac('sha256', json_encode($payload), $this->privateKey);
            
            $response = Http::withoutVerifying()
                ->withHeaders([
                    'Authorization' => 'Bearer ' . $this->apiKey,
                    'X-Signature' => $signature
                ])
                ->post($endpoint, $payload);
            
            if ($response->successful()) {
                $data = $response->json();
                
                \Log::info('Tripay refund successful', [
                    'payment_id' => $payment->id,
                    'reference' => $payment->reference
                ]);
                
                return [
                    'success' => true,
                    'data' => $data
                ];
            }
            
            \Log::error('Tripay refund failed', [
                'payment_id' => $payment->id,
                'response' => $response->body()
            ]);
            
            return [
                'success' => false,
                'message' => 'Refund request failed'
            ];
            
        } catch (\Exception $e) {
            \Log::error('Tripay refund exception: ' . $e->getMessage());
            
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }
}

config:
<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Application Name
    |--------------------------------------------------------------------------
    |
    | This value is the name of your application, which will be used when the
    | framework needs to place the application's name in a notification or
    | other UI elements where an application name needs to be displayed.
    |
    */

    'name' => env('APP_NAME', 'Laravel'),

    /*
    |--------------------------------------------------------------------------
    | Application Environment
    |--------------------------------------------------------------------------
    |
    | This value determines the "environment" your application is currently
    | running in. This may determine how you prefer to configure various
    | services the application utilizes. Set this in your ".env" file.
    |
    */

    'env' => env('APP_ENV', 'production'),

    /*
    |--------------------------------------------------------------------------
    | Application Debug Mode
    |--------------------------------------------------------------------------
    |
    | When your application is in debug mode, detailed error messages with
    | stack traces will be shown on every error that occurs within your
    | application. If disabled, a simple generic error page is shown.
    |
    */

    'debug' => (bool) env('APP_DEBUG', false),

    /*
    |--------------------------------------------------------------------------
    | Application URL
    |--------------------------------------------------------------------------
    |
    | This URL is used by the console to properly generate URLs when using
    | the Artisan command line tool. You should set this to the root of
    | the application so that it's available within Artisan commands.
    |
    */

    'url' => env('APP_URL', 'http://localhost'),

    /*
    |--------------------------------------------------------------------------
    | Application Timezone
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default timezone for your application, which
    | will be used by the PHP date and date-time functions. The timezone
    | is set to "UTC" by default as it is suitable for most use cases.
    |
    */

    'timezone' => 'UTC',

    /*
    |--------------------------------------------------------------------------
    | Application Locale Configuration
    |--------------------------------------------------------------------------
    |
    | The application locale determines the default locale that will be used
    | by Laravel's translation / localization methods. This option can be
    | set to any locale for which you plan to have translation strings.
    |
    */

    'locale' => env('APP_LOCALE', 'en'),

    'fallback_locale' => env('APP_FALLBACK_LOCALE', 'en'),

    'faker_locale' => env('APP_FAKER_LOCALE', 'en_US'),

    /*
    |--------------------------------------------------------------------------
    | Encryption Key
    |--------------------------------------------------------------------------
    |
    | This key is utilized by Laravel's encryption services and should be set
    | to a random, 32 character string to ensure that all encrypted values
    | are secure. You should do this prior to deploying the application.
    |
    */

    'cipher' => 'AES-256-CBC',

    'key' => env('APP_KEY'),

    'previous_keys' => [
        ...array_filter(
            explode(',', (string) env('APP_PREVIOUS_KEYS', ''))
        ),
    ],

    /*
    |--------------------------------------------------------------------------
    | Maintenance Mode Driver
    |--------------------------------------------------------------------------
    |
    | These configuration options determine the driver used to determine and
    | manage Laravel's "maintenance mode" status. The "cache" driver will
    | allow maintenance mode to be controlled across multiple machines.
    |
    | Supported drivers: "file", "cache"
    |
    */

    'maintenance' => [
        'driver' => env('APP_MAINTENANCE_DRIVER', 'file'),
        'store' => env('APP_MAINTENANCE_STORE', 'database'),
    ],

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Authentication Defaults
    |--------------------------------------------------------------------------
    |
    | This option defines the default authentication "guard" and password
    | reset "broker" for your application. You may change these values
    | as required, but they're a perfect start for most applications.
    |
    */

    'defaults' => [
        'guard' => env('AUTH_GUARD', 'web'),
        'passwords' => env('AUTH_PASSWORD_BROKER', 'users'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Authentication Guards
    |--------------------------------------------------------------------------
    |
    | Next, you may define every authentication guard for your application.
    | Of course, a great default configuration has been defined for you
    | which utilizes session storage plus the Eloquent user provider.
    |
    | All authentication guards have a user provider, which defines how the
    | users are actually retrieved out of your database or other storage
    | system used by the application. Typically, Eloquent is utilized.
    |
    | Supported: "session"
    |
    */

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | User Providers
    |--------------------------------------------------------------------------
    |
    | All authentication guards have a user provider, which defines how the
    | users are actually retrieved out of your database or other storage
    | system used by the application. Typically, Eloquent is utilized.
    |
    | If you have multiple user tables or models you may configure multiple
    | providers to represent the model / table. These providers may then
    | be assigned to any extra authentication guards you have defined.
    |
    | Supported: "database", "eloquent"
    |
    */

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => env('AUTH_MODEL', App\Models\User::class),
        ],

        // 'users' => [
        //     'driver' => 'database',
        //     'table' => 'users',
        // ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Resetting Passwords
    |--------------------------------------------------------------------------
    |
    | These configuration options specify the behavior of Laravel's password
    | reset functionality, including the table utilized for token storage
    | and the user provider that is invoked to actually retrieve users.
    |
    | The expiry time is the number of minutes that each reset token will be
    | considered valid. This security feature keeps tokens short-lived so
    | they have less time to be guessed. You may change this as needed.
    |
    | The throttle setting is the number of seconds a user must wait before
    | generating more password reset tokens. This prevents the user from
    | quickly generating a very large amount of password reset tokens.
    |
    */

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => env('AUTH_PASSWORD_RESET_TOKEN_TABLE', 'password_reset_tokens'),
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Password Confirmation Timeout
    |--------------------------------------------------------------------------
    |
    | Here you may define the number of seconds before a password confirmation
    | window expires and users are asked to re-enter their password via the
    | confirmation screen. By default, the timeout lasts for three hours.
    |
    */

    'password_timeout' => env('AUTH_PASSWORD_TIMEOUT', 10800),

];

<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Default Cache Store
    |--------------------------------------------------------------------------
    |
    | This option controls the default cache store that will be used by the
    | framework. This connection is utilized if another isn't explicitly
    | specified when running a cache operation inside the application.
    |
    */

    'default' => env('CACHE_STORE', 'database'),

    /*
    |--------------------------------------------------------------------------
    | Cache Stores
    |--------------------------------------------------------------------------
    |
    | Here you may define all of the cache "stores" for your application as
    | well as their drivers. You may even define multiple stores for the
    | same cache driver to group types of items stored in your caches.
    |
    | Supported drivers: "array", "database", "file", "memcached",
    |                    "redis", "dynamodb", "octane",
    |                    "failover", "null"
    |
    */

    'stores' => [

        'array' => [
            'driver' => 'array',
            'serialize' => false,
        ],

        'database' => [
            'driver' => 'database',
            'connection' => env('DB_CACHE_CONNECTION'),
            'table' => env('DB_CACHE_TABLE', 'cache'),
            'lock_connection' => env('DB_CACHE_LOCK_CONNECTION'),
            'lock_table' => env('DB_CACHE_LOCK_TABLE'),
        ],

        'file' => [
            'driver' => 'file',
            'path' => storage_path('framework/cache/data'),
            'lock_path' => storage_path('framework/cache/data'),
        ],

        'memcached' => [
            'driver' => 'memcached',
            'persistent_id' => env('MEMCACHED_PERSISTENT_ID'),
            'sasl' => [
                env('MEMCACHED_USERNAME'),
                env('MEMCACHED_PASSWORD'),
            ],
            'options' => [
                // Memcached::OPT_CONNECT_TIMEOUT => 2000,
            ],
            'servers' => [
                [
                    'host' => env('MEMCACHED_HOST', '127.0.0.1'),
                    'port' => env('MEMCACHED_PORT', 11211),
                    'weight' => 100,
                ],
            ],
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => env('REDIS_CACHE_CONNECTION', 'cache'),
            'lock_connection' => env('REDIS_CACHE_LOCK_CONNECTION', 'default'),
        ],

        'dynamodb' => [
            'driver' => 'dynamodb',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
            'table' => env('DYNAMODB_CACHE_TABLE', 'cache'),
            'endpoint' => env('DYNAMODB_ENDPOINT'),
        ],

        'octane' => [
            'driver' => 'octane',
        ],

        'failover' => [
            'driver' => 'failover',
            'stores' => [
                'database',
                'array',
            ],
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Cache Key Prefix
    |--------------------------------------------------------------------------
    |
    | When utilizing the APC, database, memcached, Redis, and DynamoDB cache
    | stores, there might be other applications using the same cache. For
    | that reason, you may prefix every cache key to avoid collisions.
    |
    */

    'prefix' => env('CACHE_PREFIX', Str::slug((string) env('APP_NAME', 'laravel')).'-cache-'),

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Here you may configure your settings for cross-origin resource sharing
    | or "CORS". This determines what cross-origin operations may execute
    | in web browsers. You are free to adjust these settings as needed.
    |
    | To learn more: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'storage/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];

<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Default Database Connection Name
    |--------------------------------------------------------------------------
    |
    | Here you may specify which of the database connections below you wish
    | to use as your default connection for database operations. This is
    | the connection which will be utilized unless another connection
    | is explicitly specified when you execute a query / statement.
    |
    */

    'default' => env('DB_CONNECTION', 'sqlite'),

    /*
    |--------------------------------------------------------------------------
    | Database Connections
    |--------------------------------------------------------------------------
    |
    | Below are all of the database connections defined for your application.
    | An example configuration is provided for each database system which
    | is supported by Laravel. You're free to add / remove connections.
    |
    */

    'connections' => [

        'sqlite' => [
            'driver' => 'sqlite',
            'url' => env('DB_URL'),
            'database' => env('DB_DATABASE', database_path('database.sqlite')),
            'prefix' => '',
            'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),
            'busy_timeout' => null,
            'journal_mode' => null,
            'synchronous' => null,
            'transaction_mode' => 'DEFERRED',
        ],

        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => env('DB_CHARSET', 'utf8mb4'),
            'collation' => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                (PHP_VERSION_ID >= 80500 ? \Pdo\Mysql::ATTR_SSL_CA : \PDO::MYSQL_ATTR_SSL_CA) => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],

        'mariadb' => [
            'driver' => 'mariadb',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => env('DB_CHARSET', 'utf8mb4'),
            'collation' => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                (PHP_VERSION_ID >= 80500 ? \Pdo\Mysql::ATTR_SSL_CA : \PDO::MYSQL_ATTR_SSL_CA) => env('MYSQL_ATTR_SSL_CA'),
            ]) : [],
        ],

        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => 'prefer',
        ],

        'sqlsrv' => [
            'driver' => 'sqlsrv',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', 'localhost'),
            'port' => env('DB_PORT', '1433'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            // 'encrypt' => env('DB_ENCRYPT', 'yes'),
            // 'trust_server_certificate' => env('DB_TRUST_SERVER_CERTIFICATE', 'false'),
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Migration Repository Table
    |--------------------------------------------------------------------------
    |
    | This table keeps track of all the migrations that have already run for
    | your application. Using this information, we can determine which of
    | the migrations on disk haven't actually been run on the database.
    |
    */

    'migrations' => [
        'table' => 'migrations',
        'update_date_on_publish' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Redis Databases
    |--------------------------------------------------------------------------
    |
    | Redis is an open source, fast, and advanced key-value store that also
    | provides a richer body of commands than a typical key-value system
    | such as Memcached. You may define your connection settings here.
    |
    */

    'redis' => [

        'client' => env('REDIS_CLIENT', 'phpredis'),

        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug((string) env('APP_NAME', 'laravel')).'-database-'),
            'persistent' => env('REDIS_PERSISTENT', false),
        ],

        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
            'max_retries' => env('REDIS_MAX_RETRIES', 3),
            'backoff_algorithm' => env('REDIS_BACKOFF_ALGORITHM', 'decorrelated_jitter'),
            'backoff_base' => env('REDIS_BACKOFF_BASE', 100),
            'backoff_cap' => env('REDIS_BACKOFF_CAP', 1000),
        ],

        'cache' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_CACHE_DB', '1'),
            'max_retries' => env('REDIS_MAX_RETRIES', 3),
            'backoff_algorithm' => env('REDIS_BACKOFF_ALGORITHM', 'decorrelated_jitter'),
            'backoff_base' => env('REDIS_BACKOFF_BASE', 100),
            'backoff_cap' => env('REDIS_BACKOFF_CAP', 1000),
        ],

    ],

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => env('APP_URL').'/storage',
            'visibility' => 'public',
            'throw' => false,
            'report' => false,
        ],

        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];

<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Firebase Credentials
    |--------------------------------------------------------------------------
    |
    | Path to your Firebase service account JSON file.
    | Download from Firebase Console > Project Settings > Service Accounts
    |
    */
    'credentials' => env('FIREBASE_CREDENTIALS'),
];

<?php

use Monolog\Handler\NullHandler;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\SyslogUdpHandler;
use Monolog\Processor\PsrLogMessageProcessor;

return [

    /*
    |--------------------------------------------------------------------------
    | Default Log Channel
    |--------------------------------------------------------------------------
    |
    | This option defines the default log channel that is utilized to write
    | messages to your logs. The value provided here should match one of
    | the channels present in the list of "channels" configured below.
    |
    */

    'default' => env('LOG_CHANNEL', 'stack'),

    /*
    |--------------------------------------------------------------------------
    | Deprecations Log Channel
    |--------------------------------------------------------------------------
    |
    | This option controls the log channel that should be used to log warnings
    | regarding deprecated PHP and library features. This allows you to get
    | your application ready for upcoming major versions of dependencies.
    |
    */

    'deprecations' => [
        'channel' => env('LOG_DEPRECATIONS_CHANNEL', 'null'),
        'trace' => env('LOG_DEPRECATIONS_TRACE', false),
    ],

    /*
    |--------------------------------------------------------------------------
    | Log Channels
    |--------------------------------------------------------------------------
    |
    | Here you may configure the log channels for your application. Laravel
    | utilizes the Monolog PHP logging library, which includes a variety
    | of powerful log handlers and formatters that you're free to use.
    |
    | Available drivers: "single", "daily", "slack", "syslog",
    |                    "errorlog", "monolog", "custom", "stack"
    |
    */

    'channels' => [

        'stack' => [
            'driver' => 'stack',
            'channels' => explode(',', (string) env('LOG_STACK', 'single')),
            'ignore_exceptions' => false,
        ],

        'single' => [
            'driver' => 'single',
            'path' => storage_path('logs/laravel.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'replace_placeholders' => true,
        ],

        'daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/laravel.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'days' => env('LOG_DAILY_DAYS', 14),
            'replace_placeholders' => true,
        ],

        'slack' => [
            'driver' => 'slack',
            'url' => env('LOG_SLACK_WEBHOOK_URL'),
            'username' => env('LOG_SLACK_USERNAME', 'Laravel Log'),
            'emoji' => env('LOG_SLACK_EMOJI', ':boom:'),
            'level' => env('LOG_LEVEL', 'critical'),
            'replace_placeholders' => true,
        ],

        'papertrail' => [
            'driver' => 'monolog',
            'level' => env('LOG_LEVEL', 'debug'),
            'handler' => env('LOG_PAPERTRAIL_HANDLER', SyslogUdpHandler::class),
            'handler_with' => [
                'host' => env('PAPERTRAIL_URL'),
                'port' => env('PAPERTRAIL_PORT'),
                'connectionString' => 'tls://'.env('PAPERTRAIL_URL').':'.env('PAPERTRAIL_PORT'),
            ],
            'processors' => [PsrLogMessageProcessor::class],
        ],

        'stderr' => [
            'driver' => 'monolog',
            'level' => env('LOG_LEVEL', 'debug'),
            'handler' => StreamHandler::class,
            'handler_with' => [
                'stream' => 'php://stderr',
            ],
            'formatter' => env('LOG_STDERR_FORMATTER'),
            'processors' => [PsrLogMessageProcessor::class],
        ],

        'syslog' => [
            'driver' => 'syslog',
            'level' => env('LOG_LEVEL', 'debug'),
            'facility' => env('LOG_SYSLOG_FACILITY', LOG_USER),
            'replace_placeholders' => true,
        ],

        'errorlog' => [
            'driver' => 'errorlog',
            'level' => env('LOG_LEVEL', 'debug'),
            'replace_placeholders' => true,
        ],

        'null' => [
            'driver' => 'monolog',
            'handler' => NullHandler::class,
        ],

        'emergency' => [
            'path' => storage_path('logs/laravel.log'),
        ],

    ],

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Mailer
    |--------------------------------------------------------------------------
    |
    | This option controls the default mailer that is used to send all email
    | messages unless another mailer is explicitly specified when sending
    | the message. All additional mailers can be configured within the
    | "mailers" array. Examples of each type of mailer are provided.
    |
    */

    'default' => env('MAIL_MAILER', 'log'),

    /*
    |--------------------------------------------------------------------------
    | Mailer Configurations
    |--------------------------------------------------------------------------
    |
    | Here you may configure all of the mailers used by your application plus
    | their respective settings. Several examples have been configured for
    | you and you are free to add your own as your application requires.
    |
    | Laravel supports a variety of mail "transport" drivers that can be used
    | when delivering an email. You may specify which one you're using for
    | your mailers below. You may also add additional mailers if needed.
    |
    | Supported: "smtp", "sendmail", "mailgun", "ses", "ses-v2",
    |            "postmark", "resend", "log", "array",
    |            "failover", "roundrobin"
    |
    */

    'mailers' => [

        'smtp' => [
            'transport' => 'smtp',
            'scheme' => env('MAIL_SCHEME'),
            'url' => env('MAIL_URL'),
            'host' => env('MAIL_HOST', '127.0.0.1'),
            'port' => env('MAIL_PORT', 2525),
            'username' => env('MAIL_USERNAME'),
            'password' => env('MAIL_PASSWORD'),
            'timeout' => null,
            'local_domain' => env('MAIL_EHLO_DOMAIN', parse_url((string) env('APP_URL', 'http://localhost'), PHP_URL_HOST)),
        ],

        'ses' => [
            'transport' => 'ses',
        ],

        'postmark' => [
            'transport' => 'postmark',
            // 'message_stream_id' => env('POSTMARK_MESSAGE_STREAM_ID'),
            // 'client' => [
            //     'timeout' => 5,
            // ],
        ],

        'resend' => [
            'transport' => 'resend',
        ],

        'sendmail' => [
            'transport' => 'sendmail',
            'path' => env('MAIL_SENDMAIL_PATH', '/usr/sbin/sendmail -bs -i'),
        ],

        'log' => [
            'transport' => 'log',
            'channel' => env('MAIL_LOG_CHANNEL'),
        ],

        'array' => [
            'transport' => 'array',
        ],

        'failover' => [
            'transport' => 'failover',
            'mailers' => [
                'smtp',
                'log',
            ],
            'retry_after' => 60,
        ],

        'roundrobin' => [
            'transport' => 'roundrobin',
            'mailers' => [
                'ses',
                'postmark',
            ],
            'retry_after' => 60,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Global "From" Address
    |--------------------------------------------------------------------------
    |
    | You may wish for all emails sent by your application to be sent from
    | the same address. Here you may specify a name and address that is
    | used globally for all emails that are sent by your application.
    |
    */

    'from' => [
        'address' => env('MAIL_FROM_ADDRESS', 'hello@example.com'),
        'name' => env('MAIL_FROM_NAME', 'Example'),
    ],

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Queue Connection Name
    |--------------------------------------------------------------------------
    |
    | Laravel's queue supports a variety of backends via a single, unified
    | API, giving you convenient access to each backend using identical
    | syntax for each. The default queue connection is defined below.
    |
    */

    'default' => env('QUEUE_CONNECTION', 'database'),

    /*
    |--------------------------------------------------------------------------
    | Queue Connections
    |--------------------------------------------------------------------------
    |
    | Here you may configure the connection options for every queue backend
    | used by your application. An example configuration is provided for
    | each backend supported by Laravel. You're also free to add more.
    |
    | Drivers: "sync", "database", "beanstalkd", "sqs", "redis",
    |          "deferred", "background", "failover", "null"
    |
    */

    'connections' => [

        'sync' => [
            'driver' => 'sync',
        ],

        'database' => [
            'driver' => 'database',
            'connection' => env('DB_QUEUE_CONNECTION'),
            'table' => env('DB_QUEUE_TABLE', 'jobs'),
            'queue' => env('DB_QUEUE', 'default'),
            'retry_after' => (int) env('DB_QUEUE_RETRY_AFTER', 90),
            'after_commit' => false,
        ],

        'beanstalkd' => [
            'driver' => 'beanstalkd',
            'host' => env('BEANSTALKD_QUEUE_HOST', 'localhost'),
            'queue' => env('BEANSTALKD_QUEUE', 'default'),
            'retry_after' => (int) env('BEANSTALKD_QUEUE_RETRY_AFTER', 90),
            'block_for' => 0,
            'after_commit' => false,
        ],

        'sqs' => [
            'driver' => 'sqs',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'prefix' => env('SQS_PREFIX', 'https://sqs.us-east-1.amazonaws.com/your-account-id'),
            'queue' => env('SQS_QUEUE', 'default'),
            'suffix' => env('SQS_SUFFIX'),
            'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
            'after_commit' => false,
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => env('REDIS_QUEUE_CONNECTION', 'default'),
            'queue' => env('REDIS_QUEUE', 'default'),
            'retry_after' => (int) env('REDIS_QUEUE_RETRY_AFTER', 90),
            'block_for' => null,
            'after_commit' => false,
        ],

        'deferred' => [
            'driver' => 'deferred',
        ],

        'background' => [
            'driver' => 'background',
        ],

        'failover' => [
            'driver' => 'failover',
            'connections' => [
                'database',
                'deferred',
            ],
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Job Batching
    |--------------------------------------------------------------------------
    |
    | The following options configure the database and table that store job
    | batching information. These options can be updated to any database
    | connection and table which has been defined by your application.
    |
    */

    'batching' => [
        'database' => env('DB_CONNECTION', 'sqlite'),
        'table' => 'job_batches',
    ],

    /*
    |--------------------------------------------------------------------------
    | Failed Queue Jobs
    |--------------------------------------------------------------------------
    |
    | These options configure the behavior of failed queue job logging so you
    | can control how and where failed jobs are stored. Laravel ships with
    | support for storing failed jobs in a simple file or in a database.
    |
    | Supported drivers: "database-uuids", "dynamodb", "file", "null"
    |
    */

    'failed' => [
        'driver' => env('QUEUE_FAILED_DRIVER', 'database-uuids'),
        'database' => env('DB_CONNECTION', 'sqlite'),
        'table' => 'failed_jobs',
    ],

];

<?php

use Laravel\Sanctum\Sanctum;

return [

    /*
    |--------------------------------------------------------------------------
    | Stateful Domains
    |--------------------------------------------------------------------------
    |
    | Requests from the following domains / hosts will receive stateful API
    | authentication cookies. Typically, these should include your local
    | and production domains which access your API via a frontend SPA.
    |
    */

    'stateful' => explode(',', env('SANCTUM_STATEFUL_DOMAINS', sprintf(
        '%s%s',
        'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000,::1',
        Sanctum::currentApplicationUrlWithPort(),
        // Sanctum::currentRequestHost(),
    ))),

    /*
    |--------------------------------------------------------------------------
    | Sanctum Guards
    |--------------------------------------------------------------------------
    |
    | This array contains the authentication guards that will be checked when
    | Sanctum is trying to authenticate a request. If none of these guards
    | are able to authenticate the request, Sanctum will use the bearer
    | token that's present on an incoming request for authentication.
    |
    */

    'guard' => ['web'],

    /*
    |--------------------------------------------------------------------------
    | Expiration Minutes
    |--------------------------------------------------------------------------
    |
    | This value controls the number of minutes until an issued token will be
    | considered expired. This will override any values set in the token's
    | "expires_at" attribute, but first-party sessions are not affected.
    |
    */

    'expiration' => null,

    /*
    |--------------------------------------------------------------------------
    | Token Prefix
    |--------------------------------------------------------------------------
    |
    | Sanctum can prefix new tokens in order to take advantage of numerous
    | security scanning initiatives maintained by open source platforms
    | that notify developers if they commit tokens into repositories.
    |
    | See: https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning
    |
    */

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    /*
    |--------------------------------------------------------------------------
    | Sanctum Middleware
    |--------------------------------------------------------------------------
    |
    | When authenticating your first-party SPA with Sanctum you may need to
    | customize some of the middleware Sanctum uses while processing the
    | request. You may change the middleware listed below as required.
    |
    */

    'middleware' => [
        'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
        'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
        'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ],

];

<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'google_maps' => [
        'key' => env('GOOGLE_MAPS_API_KEY'),
    ],

    'warehouse' => [
        'lat' => env('WAREHOUSE_LAT', -6.200000),
        'lng' => env('WAREHOUSE_LNG', 106.800000),
    ],

];

<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Default Session Driver
    |--------------------------------------------------------------------------
    |
    | This option determines the default session driver that is utilized for
    | incoming requests. Laravel supports a variety of storage options to
    | persist session data. Database storage is a great default choice.
    |
    | Supported: "file", "cookie", "database", "memcached",
    |            "redis", "dynamodb", "array"
    |
    */

    'driver' => env('SESSION_DRIVER', 'database'),

    /*
    |--------------------------------------------------------------------------
    | Session Lifetime
    |--------------------------------------------------------------------------
    |
    | Here you may specify the number of minutes that you wish the session
    | to be allowed to remain idle before it expires. If you want them
    | to expire immediately when the browser is closed then you may
    | indicate that via the expire_on_close configuration option.
    |
    */

    'lifetime' => (int) env('SESSION_LIFETIME', 120),

    'expire_on_close' => env('SESSION_EXPIRE_ON_CLOSE', false),

    /*
    |--------------------------------------------------------------------------
    | Session Encryption
    |--------------------------------------------------------------------------
    |
    | This option allows you to easily specify that all of your session data
    | should be encrypted before it's stored. All encryption is performed
    | automatically by Laravel and you may use the session like normal.
    |
    */

    'encrypt' => env('SESSION_ENCRYPT', false),

    /*
    |--------------------------------------------------------------------------
    | Session File Location
    |--------------------------------------------------------------------------
    |
    | When utilizing the "file" session driver, the session files are placed
    | on disk. The default storage location is defined here; however, you
    | are free to provide another location where they should be stored.
    |
    */

    'files' => storage_path('framework/sessions'),

    /*
    |--------------------------------------------------------------------------
    | Session Database Connection
    |--------------------------------------------------------------------------
    |
    | When using the "database" or "redis" session drivers, you may specify a
    | connection that should be used to manage these sessions. This should
    | correspond to a connection in your database configuration options.
    |
    */

    'connection' => env('SESSION_CONNECTION'),

    /*
    |--------------------------------------------------------------------------
    | Session Database Table
    |--------------------------------------------------------------------------
    |
    | When using the "database" session driver, you may specify the table to
    | be used to store sessions. Of course, a sensible default is defined
    | for you; however, you're welcome to change this to another table.
    |
    */

    'table' => env('SESSION_TABLE', 'sessions'),

    /*
    |--------------------------------------------------------------------------
    | Session Cache Store
    |--------------------------------------------------------------------------
    |
    | When using one of the framework's cache driven session backends, you may
    | define the cache store which should be used to store the session data
    | between requests. This must match one of your defined cache stores.
    |
    | Affects: "dynamodb", "memcached", "redis"
    |
    */

    'store' => env('SESSION_STORE'),

    /*
    |--------------------------------------------------------------------------
    | Session Sweeping Lottery
    |--------------------------------------------------------------------------
    |
    | Some session drivers must manually sweep their storage location to get
    | rid of old sessions from storage. Here are the chances that it will
    | happen on a given request. By default, the odds are 2 out of 100.
    |
    */

    'lottery' => [2, 100],

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Name
    |--------------------------------------------------------------------------
    |
    | Here you may change the name of the session cookie that is created by
    | the framework. Typically, you should not need to change this value
    | since doing so does not grant a meaningful security improvement.
    |
    */

    'cookie' => env(
        'SESSION_COOKIE',
        Str::slug((string) env('APP_NAME', 'laravel')).'-session'
    ),

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Path
    |--------------------------------------------------------------------------
    |
    | The session cookie path determines the path for which the cookie will
    | be regarded as available. Typically, this will be the root path of
    | your application, but you're free to change this when necessary.
    |
    */

    'path' => env('SESSION_PATH', '/'),

    /*
    |--------------------------------------------------------------------------
    | Session Cookie Domain
    |--------------------------------------------------------------------------
    |
    | This value determines the domain and subdomains the session cookie is
    | available to. By default, the cookie will be available to the root
    | domain without subdomains. Typically, this shouldn't be changed.
    |
    */

    'domain' => env('SESSION_DOMAIN'),

    /*
    |--------------------------------------------------------------------------
    | HTTPS Only Cookies
    |--------------------------------------------------------------------------
    |
    | By setting this option to true, session cookies will only be sent back
    | to the server if the browser has a HTTPS connection. This will keep
    | the cookie from being sent to you when it can't be done securely.
    |
    */

    'secure' => env('SESSION_SECURE_COOKIE'),

    /*
    |--------------------------------------------------------------------------
    | HTTP Access Only
    |--------------------------------------------------------------------------
    |
    | Setting this value to true will prevent JavaScript from accessing the
    | value of the cookie and the cookie will only be accessible through
    | the HTTP protocol. It's unlikely you should disable this option.
    |
    */

    'http_only' => env('SESSION_HTTP_ONLY', true),

    /*
    |--------------------------------------------------------------------------
    | Same-Site Cookies
    |--------------------------------------------------------------------------
    |
    | This option determines how your cookies behave when cross-site requests
    | take place, and can be used to mitigate CSRF attacks. By default, we
    | will set this value to "lax" to permit secure cross-site requests.
    |
    | See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#samesitesamesite-value
    |
    | Supported: "lax", "strict", "none", null
    |
    */

    'same_site' => env('SESSION_SAME_SITE', 'lax'),

    /*
    |--------------------------------------------------------------------------
    | Partitioned Cookies
    |--------------------------------------------------------------------------
    |
    | Setting this value to true will tie the cookie to the top-level site for
    | a cross-site context. Partitioned cookies are accepted by the browser
    | when flagged "secure" and the Same-Site attribute is set to "none".
    |
    */

    'partitioned' => env('SESSION_PARTITIONED_COOKIE', false),

];

<?php

return [
    'merchant_code' => env('TRIPAY_MERCHANT_CODE'),
    'api_key' => env('TRIPAY_API_KEY'),
    'private_key' => env('TRIPAY_PRIVATE_KEY'),
    'mode' => env('TRIPAY_MODE', 'sandbox'),
    
    'api_url' => env('TRIPAY_MODE', 'sandbox') === 'production' 
        ? 'https://tripay.co.id/api' 
        : 'https://tripay.co.id/api-sandbox',
];


routes:
<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\AdminOrderController;
use App\Http\Controllers\Api\AdminDashboardController;
use App\Http\Controllers\Api\DriverOrderController;
use App\Http\Controllers\Api\WaybillController;
use App\Http\Controllers\Api\DistanceController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\AdminDriverController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| PUBLIC ROUTES
|--------------------------------------------------------------------------
*/
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/payment/tripay/callback', [PaymentController::class, 'callback']);
Route::get('/orders/{order}/waybill/pdf', [WaybillController::class, 'downloadWaybillPdf']);

/*
|--------------------------------------------------------------------------
| PROTECTED ROUTES (Sanctum)
|--------------------------------------------------------------------------
*/
Route::middleware('auth:sanctum')->group(function () {
    
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/payments/initiate-checkout', [PaymentController::class, 'initiateCheckoutPayment']);

    /* --- PROFILE & USER --- */
    Route::prefix('profile')->group(function () {
        Route::get('/', [ProfileController::class, 'show']);
        Route::put('/', [ProfileController::class, 'update']);
        Route::put('/password', [ProfileController::class, 'changePassword']);
        Route::post('/photo', [ProfileController::class, 'uploadPhoto']);
    });
    Route::post('/fcm-token', [UserController::class, 'updateFcmToken']);

    /* --- PRODUCT ROUTES --- */
    Route::get('/products/categories', [ProductController::class, 'getCategories']);
    Route::get('/products/search', [ProductController::class, 'search']);
    Route::apiResource('products', ProductController::class)->only(['index', 'show']);

    /* --- ORDER ROUTES (General User & Tracking) --- */
    Route::prefix('orders')->group(function () {
        Route::get('/', [OrderController::class, 'index']);
        Route::post('/', [OrderController::class, 'store']);
        Route::get('/{order}', [OrderController::class, 'show']);
        Route::post('/{order}/cancel', [OrderController::class, 'cancel']);
        Route::get('/{order}/tracking', [OrderController::class, 'tracking']);
        Route::post('/{order}/pay', [PaymentController::class, 'pay']);
        
        // Endpoint untuk Flutter mengirim lokasi GPS (Update Driver Location)
        Route::post('/{order}/update-location', [OrderController::class, 'updateDriverLocation']);
        
        Route::post('/{order}/upload-photo', [OrderController::class, 'uploadPhoto']);
        Route::get('/{order}/photos', [OrderController::class, 'photos']);
        Route::get('/{order}/waybill', [OrderController::class, 'showWaybill']);
    });

    /* --- ADMIN ROUTES --- */
    Route::middleware('role:admin')->prefix('admin')->group(function () {
        Route::get('/dashboard-summary', [AdminDashboardController::class, 'summary']);
        Route::post('/products/{product}', [ProductController::class, 'update']);    
        Route::apiResource('products', ProductController::class)->only(['store', 'destroy']);
        
        Route::get('/orders', [AdminOrderController::class, 'index']);
        Route::get('/orders/{order}', [AdminOrderController::class, 'show']);
        Route::post('/orders/{order}/approve', [AdminOrderController::class, 'approve']);
        Route::post('/orders/{order}/waybill', [AdminOrderController::class, 'createWaybill']);
        Route::post('/orders/{order}/assign-driver', [AdminOrderController::class, 'assignDriver']);
        
        Route::get('/drivers', [AdminDriverController::class, 'index']);
        Route::get('/drivers/available', [AdminDriverController::class, 'available']);
    });

    /* --- DRIVER ROUTES --- */
    Route::middleware('role:driver')->prefix('driver')->group(function () {
        Route::get('/orders', [DriverOrderController::class, 'index']);
        
        // Menggunakan PUT atau POST sesuai keinginan Front-end untuk update status
        Route::post('/orders/{id}/status', [DriverOrderController::class, 'updateStatus']);
        
        // Route Track ini untuk mencatat riwayat koordinat ke tabel delivery_tracks
        Route::post('/orders/{orderId}/track', [DriverOrderController::class, 'track']);
        
        Route::post('/availability', [DriverOrderController::class, 'updateAvailability']);
    });
});

.env :
APP_NAME=Laravel
APP_ENV=local
APP_KEY=base64:XV5FIUpm0GtDDOhCKr4bGnuOoIbKf/IGLVn7eOzrlH0=
APP_DEBUG=true
APP_URL=https://unpensionable-zander-unmotioned.ngrok-free.dev

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file
# APP_MAINTENANCE_STORE=database

# PHP_CLI_SERVER_WORKERS=4

BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=cangkang_sawit
DB_USERNAME=root
DB_PASSWORD=

SESSION_DRIVER=database
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database

CACHE_STORE=database
# CACHE_PREFIX=

MEMCACHED_HOST=127.0.0.1

REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_SCHEME=null
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

VITE_APP_NAME="${APP_NAME}"

TRIPAY_MERCHANT_CODE=T47557
TRIPAY_API_KEY=DEV-EjZH3hVWDuluyX8xQzUpyIV2sQzm5YHahEt0rfLo
TRIPAY_PRIVATE_KEY=NuFhW-Q1L5Z-L7FEt-faAWB-26BFy
TRIPAY_MODE=sandbox
TRIPAY_API_URL=https://tripay.co.id/api-sandbox

GOOGLE_MAPS_API_KEY=AIzaSyDQOtvxYHnviEl-e_aQjamwVH8bQZnwh8U
WAREHOUSE_LAT=-6.174811960976456
WAREHOUSE_LNG=106.78990868029996

FIREBASE_CREDENTIALS=storage/firebase/cangkang-sawit-app-f2249-firebase-adminsdk-fbsvc-39bf245f07.json
