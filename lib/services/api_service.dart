// lib/services/api_service.dart - COMPLETE FIXED VERSION
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_data.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/pending_order.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;

  final http.Client _client = http.Client();

  ApiService._internal();

  // IMPORTANT: Update this to your actual backend URL
  final String _baseUrl = 'https://admin-ab5o.onrender.com';

  String? _csrfToken;
  String? _sessionCookie;

  // Helper to extract sessionid from a 'set-cookie' header
  String? _extractSessionId(String? cookieHeader) {
    if (cookieHeader == null) return null;
    final parts = cookieHeader.split(';');
    for (final part in parts) {
      if (part.trim().toLowerCase().startsWith('sessionid=')) {
        return part.trim();
      }
    }
    return null;
  }

  // Updates the session cookie if a new one is provided
  void _updateCookie(http.Response response) {
    final String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      final newSessionId = _extractSessionId(rawCookie);
      if (newSessionId != null) {
        _sessionCookie = newSessionId;
        // Save session cookie to SharedPreferences
        _saveSessionCookie(newSessionId);
      }
    }
  }

  Future<void> _saveSessionCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookie);
  }

  Future<void> _loadSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
  }

  Future<void> _fetchCsrfAndSessionTokens() async {
    try {
      // First, try to load saved session
      await _loadSessionCookie();
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/'),
        headers: {
          if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        },
      );
      
      _updateCookie(response);
      final csrfToken = _extractCsrfFromBody(response.body);
      if (csrfToken != null) {
        _csrfToken = csrfToken;
      } else {
        throw Exception('Failed to fetch CSRF token');
      }
    } catch (e) {
      print('Error fetching CSRF token: $e');
      throw Exception('Network error: $e');
    }
  }

  String? _extractCsrfFromBody(String body) {
    final regex = RegExp(r'name="csrfmiddlewaretoken" value="([^"]+)"');
    final match = regex.firstMatch(body);
    return match?.group(1);
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'X-CSRFToken': _csrfToken ?? '',
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      'Referer': _baseUrl,
    };
    return headers;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<Map<String, dynamic>> login(String mobile, String password) async {
    try {
      await _fetchCsrfAndSessionTokens();
      
      // Match the Django backend's expected format
      final response = await _client.post(
        Uri.parse('$_baseUrl/login/'),
        headers: {
          'Content-Type': 'application/json',
          'X-CSRFToken': _csrfToken ?? '',
          if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          'Referer': '$_baseUrl/login/',
        },
        body: jsonEncode({
          'mobile': mobile,
          'password': password,
        }),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        _updateCookie(response);
        
        final responseData = jsonDecode(response.body);
        
        // Check if login was successful
        if (responseData['success'] == true) {
          // Save login state
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          
          return {
            'success': true,
            'message': responseData['message'] ?? 'Login successful'
          };
        } else {
          return {
            'success': false,
            'message': responseData['error'] ?? 'Invalid credentials'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Network error: $e'
      };
    }
  }

  // Fixed: Get all orders from the correct endpoint
  Future<List<PendingOrder>> getAllOrders() async {
    try {
      // Use the correct endpoint from your Django backend
      final uri = Uri.parse('$_baseUrl/api/get_orders/');
      
      print('Fetching orders from: $uri');
      
      final response = await _client.get(uri, headers: _getHeaders());

      print('Orders Response Status: ${response.statusCode}');
      print('Orders Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> ordersData = responseData['orders'] ?? [];
        
        return ordersData.map((json) => PendingOrder.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      rethrow;
    }
  }

  // Fixed: Update order status with correct endpoint
  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    try {
      // Map Flutter status to Django backend status
      String backendStatus;
      switch (status.toLowerCase()) {
        case 'ready':
          backendStatus = 'ready';
          break;
        case 'pickedup':
        case 'picked_up':
          backendStatus = 'pickedup';
          break;
        default:
          backendStatus = status;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/update-order-status/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'id': orderId,
          'status': backendStatus,
        }),
      );

      print('Update Status Response: ${response.statusCode}');
      print('Update Status Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  // NEW: Handle order action (accept/reject)
  Future<Map<String, dynamic>> handleOrderAction(int orderId, String action) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/handle-order-action/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'order_id': orderId,
          'action': action,
        }),
      );

      print('Handle Action Response: ${response.statusCode}');
      print('Handle Action Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Action failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error handling order action: $e');
      rethrow;
    }
  }

  // Fixed: Get analytics data
  Future<AnalyticsData> getAnalyticsData(
    String filter, {
    String paymentFilter = 'Total',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/analytics/').replace(
        queryParameters: {
          'date_filter': filter,
          'payment_filter': paymentFilter,
        },
      );

      print('Fetching analytics from: $uri');

      final response = await _client.get(uri, headers: _getHeaders());

      print('Analytics Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return AnalyticsData.fromJson(responseData);
      } else {
        throw Exception('Failed to fetch analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching analytics: $e');
      rethrow;
    }
  }

  // Fixed: Place order with correct format
  Future<Map<String, dynamic>> placeOrder({
    required String customerName,
    required String customerMobile,
    required String paymentMethod,
    required List<CartItem> items,
    required double totalAmount,
  }) async {
    try {
      final orderData = {
        'customer_name': customerName,
        'customer_mobile': customerMobile,
        'payment_method': paymentMethod,
        'items': items.map((item) => {
          'id': item.item.id,
          'quantity': item.quantity,
        }).toList(),
      };

      print('Placing order with data: ${jsonEncode(orderData)}');

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/create-manual-order/'),
        headers: _getHeaders(),
        body: jsonEncode(orderData),
      );

      print('Place Order Response Status: ${response.statusCode}');
      print('Place Order Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) {
          throw Exception('Received an empty response from the server.');
        }
        try {
          return jsonDecode(response.body);
        } on FormatException {
          throw Exception('Failed to parse server response. Body: ${response.body}');
        }
      } else {
        throw Exception('Failed to place order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error placing order: $e');
      rethrow;
    }
  }

  // Fixed: Fetch menu items
  Future<List<MenuItem>> fetchMenuItems() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/menu-items/'),
        headers: _getHeaders(),
      );

      print('Menu Items Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['menu_items'] ?? [];
        return data.map((json) => MenuItem.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch menu items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching menu items: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/logout/'),
        headers: _getHeaders(),
      );
    } catch (e) {
      print('Logout error: $e');
    }
    
    // Clear local state
    _csrfToken = null;
    _sessionCookie = null;
    
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('session_cookie');
  }

  void dispose() {
    _client.close();
  }
}
