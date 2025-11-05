'''import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/analytics_data.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/pending_order.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;

  final http.Client _client = http.Client();

  ApiService._internal();

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
      }
    }
  }
  
  Future<void> _fetchCsrfAndSessionTokens() async {
    final response = await _client.get(Uri.parse('$_baseUrl/'));
    _updateCookie(response);
    final csrfToken = _extractCsrfFromBody(response.body);
    if (csrfToken != null) {
      _csrfToken = csrfToken;
    } else {
      throw Exception('Failed to fetch CSRF token');
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

  Future<Map<String, dynamic>> login(String mobile, String password) async {
    await _fetchCsrfAndSessionTokens();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRFToken': _csrfToken ?? '',
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        'Referer': '$_baseUrl/',
      },
      body: {
        'mobile': mobile,
        'password': password,
        'csrfmiddlewaretoken': _csrfToken ?? '',
      },
    );

    if (response.statusCode == 200) {
      _updateCookie(response);
      return jsonDecode(response.body);
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      throw Exception('Invalid credentials');
    }
    else {
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  Future<List<PendingOrder>> fetchOrders({String? dateFilter}) async {
    final uri = Uri.parse('$_baseUrl/api/order-list/')
        .replace(queryParameters: dateFilter != null ? {'date': dateFilter} : {});
    final response = await _client.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['orders'];
      return data.map((json) => PendingOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch orders: ${response.statusCode}');
    }
  }

  Future<List<PendingOrder>> getAllOrders() async {
    return fetchOrders();
  }
  
  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/update-status/'),
      headers: _getHeaders(),
      body: jsonEncode({'id': orderId, 'status': status}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Update failed: ${response.statusCode}');
    }
  }

  Future<AnalyticsData> getAnalyticsData(String filter,
      {String paymentFilter = 'all'}) async {
    final uri = Uri.parse('$_baseUrl/api/analytics/').replace(queryParameters: {
      'date_filter': filter,
      'payment_filter': paymentFilter,
    });
    final response = await _client.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      return AnalyticsData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch analytics: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> placeOrder({
    required String customerName,
    required String customerMobile,
    required String paymentMethod,
    required List<CartItem> items,
  }) async {
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

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/create-manual-order/'),
      headers: _getHeaders(),
      body: jsonEncode(orderData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Check for an empty response body
      if (response.body.isEmpty) {
        throw Exception('Received an empty response from the server.');
      }
      try {
        return jsonDecode(response.body);
      } on FormatException {
         throw Exception('Failed to parse server response. Body: ${response.body}');
      }
    } else {
      throw Exception('Failed to place order: ${response.statusCode}');
    }
  }

  Future<List<MenuItem>> fetchMenuItems() async {
    final response =
        await _client.get(Uri.parse('$_baseUrl/api/menu-items/'), headers: _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['menu_items'];
      return data.map((json) => MenuItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch menu items: ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    await _client.post(
      Uri.parse('$_baseUrl/logout/'),
      headers: _getHeaders(),
    );
    _csrfToken = null;
    _sessionCookie = null;
  }

  void dispose() {
    _client.close();
  }
}
''