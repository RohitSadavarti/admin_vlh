// lib/services/api_service.dart - FIXED VERSION
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

  // Your backend URL
  final String _baseUrl = 'https://admin-ab5o.onrender.com';

  String? _csrfToken;
  String? _sessionCookie;

  // Extract sessionid from set-cookie header
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

  // Update session cookie
  void _updateCookie(http.Response response) {
    final String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      final newSessionId = _extractSessionId(rawCookie);
      if (newSessionId != null) {
        _sessionCookie = newSessionId;
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

  // CRITICAL FIX: Get CSRF token from root page
  Future<void> _fetchCsrfAndSessionTokens() async {
    try {
      await _loadSessionCookie();

      final response = await _client.get(
        Uri.parse('$_baseUrl/'),
        headers: {
          if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        },
      );

      print('CSRF Response Status: ${response.statusCode}');
      print('CSRF Response Headers: ${response.headers}');

      _updateCookie(response);

      // Extract CSRF from HTML or cookies
      String? csrfToken =
          _extractCsrfFromCookies(response.headers['set-cookie']);
      if (csrfToken == null) {
        csrfToken = _extractCsrfFromBody(response.body);
      }

      if (csrfToken != null) {
        _csrfToken = csrfToken;
        print('✅ CSRF Token obtained: ${_csrfToken?.substring(0, 10)}...');
      } else {
        throw Exception('Failed to fetch CSRF token');
      }
    } catch (e) {
      print('❌ Error fetching CSRF token: $e');
      rethrow;
    }
  }

  String? _extractCsrfFromCookies(String? cookieHeader) {
    if (cookieHeader == null) return null;
    final regex = RegExp(r'csrftoken=([^;]+)');
    final match = regex.firstMatch(cookieHeader);
    return match?.group(1);
  }

  String? _extractCsrfFromBody(String body) {
    final regex = RegExp(r'name="csrfmiddlewaretoken"\s+value="([^"]+)"');
    final match = regex.firstMatch(body);
    return match?.group(1);
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'X-CSRFToken': _csrfToken ?? '',
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      'Referer': _baseUrl,
    };
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // FIXED: Login with proper Django format
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    try {
      await _fetchCsrfAndSessionTokens();

      print('🔐 Attempting login for mobile: $mobile');

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

        if (responseData['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          print('✅ Login successful!');

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
      } else if (response.statusCode == 302) {
        // Handle redirect - Django redirects to dashboard on successful login
        _updateCookie(response);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        return {'success': true, 'message': 'Login successful'};
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // FIXED: Get all orders using the correct Django endpoint
  Future<List<PendingOrder>> getAllOrders() async {
    try {
      // Use the endpoint that exists in your Django urls.py
      final uri = Uri.parse('$_baseUrl/api/all-orders/');

      print('📡 Fetching orders from: $uri');

      final response = await _client.get(uri, headers: _getHeaders());

      print('Orders Response Status: ${response.statusCode}');
      print('Orders Response Body: ${response.body.substring(0, 200)}...');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle both possible response formats
        List<dynamic> ordersData;
        if (responseData is List) {
          ordersData = responseData;
        } else if (responseData is Map && responseData.containsKey('orders')) {
          ordersData = responseData['orders'];
        } else {
          throw Exception('Unexpected response format');
        }

        print('✅ Found ${ordersData.length} orders');

        return ordersData.map((json) => PendingOrder.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching orders: $e');
      rethrow;
    }
  }

  // FIXED: Update order status
  Future<Map<String, dynamic>> updateOrderStatus(
      int orderId, String status) async {
    try {
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

      print('📤 Updating order $orderId to status: $backendStatus');

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
      print('❌ Error updating order status: $e');
      rethrow;
    }
  }

  // FIXED: Get analytics data
  Future<AnalyticsData> getAnalyticsData(
    String filter, {
    String paymentFilter = 'all',
  }) async {
    try {
      // Convert filter names to match Django backend
      String djangoFilter = filter;
      switch (filter) {
        case 'this_month':
          djangoFilter = 'this_month';
          break;
        case 'this_week':
          djangoFilter = 'this_week';
          break;
        case 'today':
          djangoFilter = 'today';
          break;
      }

      final uri = Uri.parse('$_baseUrl/api/analytics/').replace(
        queryParameters: {
          'date_filter': djangoFilter,
          'payment_filter': paymentFilter == 'all' ? 'Total' : paymentFilter,
        },
      );

      print('📊 Fetching analytics from: $uri');

      final response = await _client.get(uri, headers: _getHeaders());

      print('Analytics Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ Analytics data received');
        return AnalyticsData.fromJson(responseData);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication required. Please log in again.');
      } else {
        throw Exception('Failed to fetch analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching analytics: $e');
      rethrow;
    }
  }

  // FIXED: Place order
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
        'items': items
            .map((item) => {
                  'id': item.item.id,
                  'quantity': item.quantity,
                })
            .toList(),
      };

      print('📝 Placing order: ${jsonEncode(orderData)}');

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/create-manual-order/'),
        headers: _getHeaders(),
        body: jsonEncode(orderData),
      );

      print('Place Order Response Status: ${response.statusCode}');
      print('Place Order Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('✅ Order placed successfully!');
        return result;
      } else {
        throw Exception(
            'Failed to place order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error placing order: $e');
      rethrow;
    }
  }

  // FIXED: Fetch menu items
  Future<List<MenuItem>> fetchMenuItems() async {
    try {
      print('📋 Fetching menu items...');

      final response = await _client.get(
        Uri.parse('$_baseUrl/api/menu-items/'),
        headers: _getHeaders(),
      );

      print('Menu Items Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> data = responseData['menu_items'] ?? [];
        print('✅ Found ${data.length} menu items');
        return data.map((json) => MenuItem.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication required');
      } else {
        throw Exception('Failed to fetch menu items: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching menu items: $e');
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

    _csrfToken = null;
    _sessionCookie = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('session_cookie');
  }

  void dispose() {
    _client.close();
  }
}
