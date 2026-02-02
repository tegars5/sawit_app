Implementation Plan - Forgot Password Backend
The user requires a backend endpoint to handle "Forgot Password" requests from the mobile app. This endpoint should accept an email address and trigger the standard Laravel password reset email.

User Review Required
NOTE

This implementation relies on Laravel's default password reset broker and email configuration. Ensure your .env file has valid MAIL\_\* settings (SMTP, Mailgun, etc.) for emails to actually send. The reset link in the email will point to the web URL defined in your app config. You may need to handle the actual password reset page on your web frontend or configure deep linking if you want it to open the app directly (which requires more complex setup). For now, we are just implementing the sending of the email.

Proposed Changes
Routes
[MODIFY]
api.php
Add Route::post('/forgot-password', [AuthController::class, 'forgotPassword']); to the public routes section.
Controllers
[MODIFY]
AuthController.php
Add use Illuminate\Support\Facades\Password;
Add forgotPassword(Request $request) method:
Validate email exists.
Call Password::sendResetLink($request->only('email')).
Return JSON response: { "status": "success", "message": "..." } on success, or 400/422 on failure.
Verification Plan
Manual Verification
Start Server: Ensure php artisan serve is running.
Test Endpoint: Use a tool like curl or Postman (or the Flutter app if ready) to POST to http://localhost:8000/api/forgot-password with:
{
"email": "test@example.com"
}
Check Response:
If email exists: Expect 200 OK + "We have emailed your password reset link."
If email missing: Expect 422 Validation Error.
Check Logs: Verify in
storage/logs/laravel.log
if mail sending was attempted (or check Mailtrap/Inbox if configured).

 <?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\AdminOrderController;
use App\Http\Controllers\Api\AdminDashboardController;
use App\Http\Controllers\Api\AdminReportController;
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
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);

// ✅ ROUTE 1: Untuk Driver (Download Waybill)
// Removed 'signed' middleware karena Ngrok mengubah URL (HTTP→HTTPS) yang membuat signature invalid
// Security: Rate limiting + controller validation sudah cukup
Route::get('/waybill/{id}/download', [WaybillController::class, 'generate'])
    ->name('api.waybill.generate')
    ->middleware('throttle:60,1');

// ✅ ROUTE 2: Untuk Admin/User (Preview PDF) + 🛡️ SECURITY PATCH
// Rate limiting: Max 60 requests per minute (mencegah brute force)
// URL: /api/orders/{order}/waybill/pdf
Route::get('/orders/{order}/waybill/pdf', [WaybillController::class, 'downloadWaybillPdf'])
    ->middleware('throttle:60,1');

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
        
        // Product routes
        Route::post('/products', [ProductController::class, 'store']);
        Route::post('/products/{product}', [ProductController::class, 'update']);
        Route::delete('/products/{product}', [ProductController::class, 'destroy']);
        
        Route::get('/orders', [AdminOrderController::class, 'index']);
        Route::get('/orders/{order}', [AdminOrderController::class, 'show']);
        Route::post('/orders/{order}/approve', [AdminOrderController::class, 'approve']);
        Route::post('/orders/{order}/waybill', [AdminOrderController::class, 'createWaybill']);
        Route::post('/orders/{order}/assign-driver', [AdminOrderController::class, 'assignDriver']);
        
        Route::get('/drivers', [AdminDriverController::class, 'index']);
        Route::post('/drivers', [AdminDriverController::class, 'store']);
        Route::put('/drivers/{driver}', [AdminDriverController::class, 'update']);
        Route::delete('/drivers/{driver}', [AdminDriverController::class, 'destroy']);
        Route::get('/drivers/available', [AdminDriverController::class, 'available']);
        Route::get('/reports', [AdminReportController::class, 'index']);
    });

    /* --- DRIVER ROUTES --- */
    Route::middleware('role:driver')->prefix('driver')->group(function () {
        Route::get('/orders', [DriverOrderController::class, 'index']);
        Route::post('/orders/{id}/status', [DriverOrderController::class, 'updateStatus']);
        Route::post('/orders/{id}/complete', [DriverOrderController::class, 'completeDelivery']);
        Route::post('/orders/{id}/track', [DriverOrderController::class, 'track']);
        Route::post('/availability', [DriverOrderController::class, 'updateAvailability']);
    });
});



<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Password;

class AuthController
{
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8|confirmed',
        ]);

        // Public registration is only allowed for mitra role
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => 'mitra',
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

    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => 'required|email']);

        $status = Password::sendResetLink($request->only('email'));

        if ($status === Password::RESET_LINK_SENT) {
            return response()->json(['status' => trans($status)]);
        }

        throw ValidationException::withMessages([
            'email' => [trans($status)],
        ]);
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
        'vehicle_type',
        'vehicle_number',
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
