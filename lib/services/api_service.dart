// lib/services/api_service.dart
import 'dart:async'; // Added for timeout
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_data.dart';
import '../models/cart_item.dart'; // Make sure CartItem model is imported
import '../models/menu_item.dart';
import '../models/pending_order.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  ApiService._internal();

  final String _baseUrl = "https://admin-ab5o.onrender.com"; // Ensure this is your correct backend URL

  // --- Get authentication headers ---
  Future<Map<String, String>> _getAuthHeaders() async {
    // ... (Keep this function as it was) ...
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionCookie = prefs.getString('sessionCookie');
      String? csrfToken = prefs.getString('csrfToken');

      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Referer': _baseUrl, // Often needed for CSRF validation
      };

      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      if (csrfToken != null && csrfToken.isNotEmpty) {
        headers['X-CSRFToken'] = csrfToken;
      }
      return headers;
    } catch (e) {
      return {
        'Content-Type': 'application/json; charset=UTF-8',
        'Referer': _baseUrl,
      };
    }
  }

  // --- Login method ---
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      String? csrfToken;
      try {
        final csrfResponse = await http.get(Uri.parse('$_baseUrl/')).timeout(const Duration(seconds: 15));
        String? rawCookie = csrfResponse.headers['set-cookie'];
        if (rawCookie != null) {
          RegExp csrfExp = RegExp(r'csrftoken=([^;]+)');
          Match? csrfMatch = csrfExp.firstMatch(rawCookie);
          if (csrfMatch != null) {
            csrfToken = csrfMatch.group(1);
            await prefs.setString('csrfToken', csrfToken!); 
          }
        }
      } catch (e) {
        csrfToken = prefs.getString('csrfToken');
      }

      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': _baseUrl,
      };

      if (csrfToken != null) {
        headers['X-CSRFToken'] = csrfToken;
        headers['Cookie'] = 'csrftoken=$csrfToken'; 
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/'), 
        headers: headers,
        body: {
          'mobile': mobile, 
          'password': password,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String? receivedCookies = response.headers['set-cookie'];
        String? sessionValue;
        String? finalCsrfToken = csrfToken;

        if (receivedCookies != null) {
          RegExp sessionExp = RegExp(r'sessionid=([^;]+)');
          Match? sessionMatch = sessionExp.firstMatch(receivedCookies);
          if (sessionMatch != null) {
            sessionValue = "sessionid=${sessionMatch.group(1)!}";
          } 
          RegExp csrfExp = RegExp(r'csrftoken=([^;]+)');
          Match? csrfMatch = csrfExp.firstMatch(receivedCookies);
          if (csrfMatch != null) {
            finalCsrfToken = csrfMatch.group(1)!;
            await prefs.setString('csrfToken', finalCsrfToken);
          }
        } else {
          sessionValue = prefs.getString('sessionCookie')?.split(';').firstWhere((c) => c.trim().startsWith('sessionid='), orElse: () => '');
        }

        if (sessionValue != null && sessionValue.isNotEmpty) {
          String cookieString = sessionValue;
          if (finalCsrfToken != null) {
            cookieString += "; csrftoken=$finalCsrfToken";
          }

          await prefs.setString('sessionCookie', cookieString);
          await prefs.setBool('isLoggedIn', true);
          return json.decode(response.body);
        } 
      }
      await prefs.remove('sessionCookie');
      await prefs.remove('csrfToken');
      await prefs.setBool('isLoggedIn', false);
      return {'success': false, 'message': 'Login failed'};
    } catch (e) {
      await prefs.remove('sessionCookie');
      await prefs.remove('csrfToken');
      await prefs.setBool('isLoggedIn', false);
      rethrow;
    }
  }

  Future<List<MenuItem>> fetchMenuItems() async {
    final url = Uri.parse('$_baseUrl/api/menu-items/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        Map<String, dynamic> decoded = json.decode(response.body);
        if (decoded.containsKey('menu_items') && decoded['menu_items'] is List) {
          List<dynamic> jsonResponse = decoded['menu_items'];
          List<MenuItem> items = [];
          for(var itemJson in jsonResponse) {
            try {
              items.add(MenuItem.fromJson(itemJson));
            } catch (e) {
              print("❌ Error parsing individual menu item: $e");
            }
          }
          return items;
        } else {
          throw Exception("Invalid response format: 'menu_items' key missing or invalid.");
        }
      } else {
        throw Exception('Failed to load menu items (Status code: ${response.statusCode})');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Could not connect to server. Please check your internet connection.');
      }
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('An unknown error occurred while fetching menu items.');
      }
    }
  }


  Future<Map<String, dynamic>> placeOrder(
      String customerName,
      String customerMobile,
      String paymentMethod,
      List<CartItem> cartItems,
      double totalPrice) async {
    final url = Uri.parse('$_baseUrl/api/create-manual-order/');
    try {
      List<Map<String, dynamic>> itemsPayload = cartItems
          .map((cartItem) => {
                'id': cartItem.item.id,
                'quantity': cartItem.quantity,
              })
          .toList();

      final body = json.encode({
        'customer_name': customerName,
        'customer_mobile': customerMobile,
        'payment_method': paymentMethod,
        'items': itemsPayload,
      });

      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? 'Order placement failed on server.';
          throw Exception(errorMsg);
        }
      } else if (response.statusCode == 400) {
        try {
          final responseData = json.decode(response.body);
          final errorMsg = responseData['error'] ?? 'Invalid order data submitted.';
          throw Exception(errorMsg);
        } catch(e) {
          throw Exception('Invalid order data submitted.');
        }
      } else {
        throw Exception('Failed to place order. Server error occurred.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PendingOrder>> fetchOrders({String? dateFilter}) async {
    final headers = await _getAuthHeaders();
    
    final queryParameters = {
      'date_filter': dateFilter ?? 'this_year'
    };

    final url =
        Uri.parse('$_baseUrl/api/all-orders/').replace(queryParameters: queryParameters);

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().startsWith('<!DOCTYPE')) {
        await logout();
        throw Exception('Authentication failed. Please log in again.');
      }

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            List<dynamic> ordersJson = jsonResponse['orders'];
            List<PendingOrder> orders = [];
            for (var i = 0; i < ordersJson.length; i++) {
              try {
                orders.add(PendingOrder.fromJson(ordersJson[i]));
              } catch (e) {
                print("❌ Error parsing order at index $i: $e");
              }
            }
            return orders;
          } else {
            throw Exception(jsonResponse['error'] ?? 'Failed to fetch orders');
          }
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Invalid response format received from server.');
          }
          rethrow;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        throw Exception('Failed to load orders. Server error occurred.');
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<bool> updateOrderStatus(int orderDbId, String action) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$_baseUrl/api/handle-order-action/');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'order_id': orderDbId,
          'action': action,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.body.trim().startsWith('<!DOCTYPE')) {
        await logout();
        throw Exception('Authentication failed. Please log in again.');
      }

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            return true;
          } else {
            throw Exception(jsonResponse['error'] ?? 'Order action failed on server.');
          }
        } catch (e) {
          return false;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to process order action.');
        } catch(e) {
          throw Exception('Failed to process order action. Server error occurred.');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<AnalyticsData> getAnalyticsData({String? dateFilter, String? paymentFilter}) async {
    final headers = await _getAuthHeaders();
    final queryParameters = {
      'date_filter': dateFilter ?? 'this_month',
      'payment_filter': paymentFilter ?? 'all',
    };

    final url = Uri.parse('$_baseUrl/api/analytics/').replace(queryParameters: queryParameters);

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.body.trim().startsWith('<!DOCTYPE')) {
        await logout();
        throw Exception('Authentication failed. Please log in again.');
      }

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('[v0] Analytics API Response: totalRevenue=${jsonData['key_metrics']?['total_revenue']}, totalOrders=${jsonData['key_metrics']?['total_orders']}');
          return AnalyticsData.fromJson(jsonData);
        } catch (e) {
          print('[v0] Error parsing analytics data: $e');
          throw Exception('Received invalid analytics data format from server.');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('[v0] Analytics API Error Status: ${response.statusCode}');
        throw Exception('Failed to load analytics data. Server error occurred.');
      }
    } catch (e) {
      print('[v0] Analytics API Exception: $e');
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final sessionCookie = prefs.getString('sessionCookie');

      bool hasSessionId = sessionCookie != null && sessionCookie.contains('sessionid=');

      return isLoggedIn && hasSessionId;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sessionCookie');
      await prefs.remove('csrfToken');
      await prefs.setBool('isLoggedIn', false);
    } catch (e) {
      print("❌ Error clearing local session during logout: $e");
    }
  }

  void dispose(){
    // No-op for now, as http.Client is not stored as a long-term instance variable.
  }
}
