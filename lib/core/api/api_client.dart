import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/paginated_response.dart';
import '../models/tracking_response.dart';
import '../models/payment_response.dart';

class ApiClient {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ========== AUTH APIs ==========

  Future<AuthResponse> register(Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/register'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<User> getCurrentUser() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/me'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<void> logout() async {
    await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/logout'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));
  }

  // ========== PROFILE APIs ==========

  Future<User> getProfile() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/profile'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}/profile'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return User.fromJson(json['user']);
    }
    throw _handleError(response);
  }

  Future<void> changePassword(Map<String, dynamic> data) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}/profile/password'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/fcm-token'),
          headers: _headers,
          body: jsonEncode({'fcm_token': fcmToken}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));
  }

  // ========== PRODUCT APIs ==========

  Future<PaginatedResponse<Product>> getProducts({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/products?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Product>.fromJson(
        jsonDecode(response.body),
        (json) => Product.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<PaginatedResponse<Product>> searchProducts({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/products/search')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Product>.fromJson(
        jsonDecode(response.body),
        (json) => Product.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<Product> getProduct(int productId) async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/products/$productId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  /// Create new product (Admin only)
  Future<Product> createProduct(
    Map<String, dynamic> productData, {
    File? imageFile,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/products'),
    );

    request.headers.addAll({
      'Authorization': _headers['Authorization']!,
      'Accept': 'application/json',
    });

    request.fields['name'] = productData['name'].toString();
    request.fields['description'] = productData['description'].toString();
    request.fields['category'] = productData['category'].toString();
    request.fields['price'] = productData['price'].toString();
    request.fields['stock'] = productData['stock'].toString();

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Product.fromJson(json['product']);
    }
    throw _handleError(response);
  }

  /// Update product (Admin only)
  Future<Product> updateProduct(
    int productId,
    Map<String, dynamic> productData, {
    File? imageFile,
  }) async {
    // Use POST with _method=PUT for multipart compatibility
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/products/$productId'),
    );

    request.headers.addAll({
      'Authorization': _headers['Authorization'] ?? '',
      'Accept': 'application/json',
    });

    // Add product data
    request.fields['name'] = productData['name'].toString();
    request.fields['description'] = productData['description'].toString();
    request.fields['category'] = productData['category'].toString();
    request.fields['price'] = productData['price'].toString();
    request.fields['stock'] = productData['stock'].toString();

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Product.fromJson(json['product']);
    }
    throw _handleError(response);
  }

  /// Delete product (Admin only)
  Future<void> deleteProduct(int productId) async {
    final response = await http
        .delete(
          Uri.parse('${AppConfig.baseUrl}/products/$productId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // ========== ORDER APIs ==========

  Future<PaginatedResponse<Order>> getOrders({
    int page = 1,
    int perPage = 15,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/orders')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Order>.fromJson(
        jsonDecode(response.body),
        (json) => Order.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<Order> getOrder(int orderId) async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<Map<String, dynamic>> initiateCheckoutPayment({
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/payments/initiate-checkout'),
          headers: _headers,
          body: jsonEncode({
            'destination_address': destinationAddress,
            'destination_lat': destinationLat,
            'destination_lng': destinationLng,
            'items': items,
            'payment_method': paymentMethod,
          }),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _handleError(response);
  }

  Future<Order> createOrder(Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      // Debug: Print response to see structure
      print('=== CREATE ORDER RESPONSE ===');
      print(response.body);
      print('============================');

      final jsonResponse = jsonDecode(response.body);
      return Order.fromJson(jsonResponse);
    }
    throw _handleError(response);
  }

  Future<Order> cancelOrder(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/cancel'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Order.fromJson(json['order']);
    }
    throw _handleError(response);
  }

  // ========== TRACKING API ==========

  Future<TrackingResponse> getOrderTracking(int orderId) async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/tracking'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return TrackingResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  // ========== PAYMENT API ==========

  Future<PaymentResponse> createPayment(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/pay'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaymentResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  // ========== ADMIN APIs ==========

  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/admin/dashboard-summary'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _handleError(response);
  }

  Future<PaginatedResponse<Order>> getAdminOrders({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/admin/orders')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Order>.fromJson(
        jsonDecode(response.body),
        (json) => Order.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<void> approveOrder(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/admin/orders/$orderId/approve'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> assignDriver(int orderId, int driverId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/admin/orders/$orderId/assign-driver'),
          headers: _headers,
          body: jsonEncode({'driver_id': driverId}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<PaginatedResponse<User>> getDrivers({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/admin/drivers?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<User>.fromJson(
        jsonDecode(response.body),
        (json) => User.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<List<User>> getAvailableDrivers() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/admin/drivers/available'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    }
    throw _handleError(response);
  }

  // ========== DRIVER APIs ==========

  Future<PaginatedResponse<Order>> getDriverOrders({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/driver/orders?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Order>.fromJson(
        jsonDecode(response.body),
        (json) => Order.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<void> updateAvailability(String status) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/driver/availability'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> updateDeliveryStatus(int deliveryId, String status) async {
    final response = await http
        .post(
          Uri.parse(
              '${AppConfig.baseUrl}/driver/delivery-orders/$deliveryId/status'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> updateDriverLocation(
      int deliveryId, double lat, double lng) async {
    final response = await http
        .post(
          Uri.parse(
              '${AppConfig.baseUrl}/driver/delivery-orders/$deliveryId/track'),
          headers: _headers,
          body: jsonEncode({'lat': lat, 'lng': lng}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // ========== ALIAS METHODS (for backward compatibility) ==========

  /// Alias for getOrderTracking
  Future<TrackingResponse> trackOrder(int orderId) => getOrderTracking(orderId);

  /// Alias for createPayment
  Future<PaymentResponse> processPayment(
      int orderId, String paymentMethod) async {
    // For now, just call createPayment. In future, can pass paymentMethod
    return createPayment(orderId);
  }

  /// Alias for updateAvailability
  Future<void> updateDriverAvailability(String status) async {
    return updateAvailability(status);
  }

  // ========== ERROR HANDLING ==========

  Exception _handleError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      final message = json['message'] ?? 'An error occurred';
      return Exception('Error ${response.statusCode}: $message');
    } catch (e) {
      return Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
