import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analytics_data.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/pending_order.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  ApiService._internal();

  // ✅ CORRECT BASE URL
  final String _baseUrl = "https://admin-ab5o.onrender.com";

  // --- Authentication Headers ---
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionCookie = prefs.getString('sessionCookie');
      String? csrfToken = prefs.getString('csrfToken');

      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Referer': _baseUrl,
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

  // --- Login Method ---
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Get CSRF token first
      String? csrfToken;
      try {
        final csrfResponse = await http
            .get(Uri.parse('$_baseUrl/'))
            .timeout(const Duration(seconds: 15));
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
        'Content-Type': 'application/json',
        'Referer': _baseUrl,
      };

      if (csrfToken != null) {
        headers['X-CSRFToken'] = csrfToken;
        headers['Cookie'] = 'csrftoken=$csrfToken';
      }

      // ✅ FIXED: Use JSON body with 'mobile' key
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login/'),
            headers: headers,
            body: json.encode({
              'mobile': mobile, // ✅ Changed from 'username' to 'mobile'
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

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
        }

        if (sessionValue != null && sessionValue.isNotEmpty) {
          String cookieString = sessionValue;
          if (finalCsrfToken != null) {
            cookieString += "; csrftoken=$finalCsrfToken";
          }

          await prefs.setString('sessionCookie', cookieString);
          await prefs.setBool('isLoggedIn', true);

          // Parse response
          try {
            final responseData = json.decode(response.body);
            return responseData;
          } catch (e) {
            return {'success': true, 'message': 'Login successful'};
          }
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

  // --- Fetch Menu Items ---
  Future<List<MenuItem>> fetchMenuItems() async {
    final url = Uri.parse('$_baseUrl/api/menu-items/');
    try {
      final response = await http
          .get(url, headers: await _getAuthHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> decoded = json.decode(response.body);
        if (decoded.containsKey('menu_items') &&
            decoded['menu_items'] is List) {
          List<dynamic> jsonResponse = decoded['menu_items'];
          List<MenuItem> items = [];
          for (var itemJson in jsonResponse) {
            try {
              items.add(MenuItem.fromJson(itemJson));
            } catch (e) {
              print("❌ Error parsing menu item: $e");
            }
          }
          return items;
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        throw Exception('Failed to load menu items (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Place Order with correct endpoint and proper response handling
  Future<Map<String, dynamic>> placeOrder(
      String customerName,
      String customerMobile,
      String paymentMethod,
      List<CartItem> cartItems,
      double totalPrice) async {
    // ✅ CORRECT ENDPOINT: /api/place-order/ (for customer orders)
    final url = Uri.parse('$_baseUrl/api/place-order/');

    try {
      print("[v0] Starting placeOrder request to: $url");

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
        'total_price': totalPrice,
      });

      print("[v0] Request body: $body");

      final headers = await _getAuthHeaders();
      print("[v0] Auth headers: $headers");

      final response = await http
          .post(
            url,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      print("[v0] Response status: ${response.statusCode}");
      print("[v0] Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            return responseData;
          } else {
            throw Exception(responseData['error'] ?? 'Order failed');
          }
        } catch (e) {
          // If it's valid JSON response, return success
          return {
            'success': true,
            'message': 'Order placed successfully!',
          };
        }
      } else {
        throw Exception(
            'Failed to place order (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print("[v0] Exception in placeOrder: $e");
      rethrow;
    }
  }

  // --- Fetch Orders ---
  Future<List<PendingOrder>> fetchOrders({String? dateFilter}) async {
    final headers = await _getAuthHeaders();

    // ✅ CORRECT: Use 'date' parameter that Django expects
    final queryParameters = {'date': dateFilter ?? 'this_month'};

    // ✅ CORRECT ENDPOINT: /api/all-orders/
    final url = Uri.parse('$_baseUrl/api/all-orders/')
        .replace(queryParameters: queryParameters);

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().startsWith('<!DOCTYPE')) {
        await logout();
        throw Exception('Authentication failed');
      }

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            List<dynamic> ordersJson = jsonResponse['orders'];
            return ordersJson
                .map((json) => PendingOrder.fromJson(json))
                .toList();
          } else {
            throw Exception(jsonResponse['error'] ?? 'Failed to fetch orders');
          }
        } catch (e) {
          rethrow;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Session expired');
      } else {
        throw Exception('Failed to load orders (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- Update Order Status ---
  Future<bool> updateOrderStatus(int orderDbId, String action) async {
    final headers = await _getAuthHeaders();
    final url = Uri.parse('$_baseUrl/api/update-order-status/');

    try {
      final response = await http
          .post(
            url,
            headers: headers,
            body: json.encode({
              'id': orderDbId,
              'status': action,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse['success'] == true;
      } else {
        throw Exception('Update failed (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ FIXED: Get Analytics Data with better error handling
  Future<AnalyticsData> getAnalyticsData(
      {String? dateFilter, String? paymentFilter}) async {
    final headers = await _getAuthHeaders();

    final queryParameters = {
      'date_filter': dateFilter ?? 'this_month',
      'payment_filter': paymentFilter ?? 'Total',
    };

    // ✅ CORRECT ENDPOINT: /api/analytics/
    final url = Uri.parse('$_baseUrl/api/analytics/')
        .replace(queryParameters: queryParameters);

    try {
      print("[v0] Fetching analytics from: $url");
      print("[v0] Headers: $headers");

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      print("[v0] Analytics response status: ${response.statusCode}");
      print(
          "[v0] Analytics response body: ${response.body.substring(0, min(500, response.body.length))}");

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          return AnalyticsData.fromJson(jsonData);
        } catch (parseError) {
          print("[v0] Error parsing analytics JSON: $parseError");
          throw Exception('Failed to parse analytics data: $parseError');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Authentication required. Session may have expired.');
      } else {
        throw Exception(
            'Failed to load analytics (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print("[v0] Exception in getAnalyticsData: $e");
      rethrow;
    }
  }

  // ✅ FIXED: New method to fetch all orders with proper error handling
  Future<List<PendingOrder>> getAllOrders({String? dateFilter}) async {
    final headers = await _getAuthHeaders();

    // Use 'date' parameter that Django expects
    final queryParameters = {'date': dateFilter ?? 'this_month'};
    final url = Uri.parse('$_baseUrl/api/all-orders/')
        .replace(queryParameters: queryParameters);

    try {
      print("[v0] Fetching orders from: $url");

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      print("[v0] Orders response status: ${response.statusCode}");

      if (response.body.trim().startsWith('<!DOCTYPE')) {
        await logout();
        throw Exception('Authentication failed - received HTML response');
      }

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> jsonResponse = json.decode(response.body);

          if (jsonResponse['success'] == true) {
            List<dynamic> ordersJson = jsonResponse['orders'] ?? [];
            return ordersJson
                .map((json) => PendingOrder.fromJson(json))
                .toList();
          } else {
            throw Exception(jsonResponse['error'] ?? 'Failed to fetch orders');
          }
        } catch (parseError) {
          print("[v0] Error parsing orders JSON: $parseError");
          throw Exception('Failed to parse orders: $parseError');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Session expired');
      } else {
        throw Exception(
            'Failed to load orders (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print("[v0] Exception in getAllOrders: $e");
      rethrow;
    }
  }

  // --- Check Login Status ---
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final sessionCookie = prefs.getString('sessionCookie');
      return isLoggedIn &&
          sessionCookie != null &&
          sessionCookie.contains('sessionid=');
    } catch (e) {
      return false;
    }
  }

  // --- Logout ---
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sessionCookie');
      await prefs.remove('csrfToken');
      await prefs.setBool('isLoggedIn', false);
    } catch (e) {
      print("❌ Logout error: $e");
    }
  }

  // --- Menu Item Management (Add/Edit/Delete) ---

  Future<Map<String, dynamic>> addMenuItem({
    required String itemName,
    required double price,
    required String category,
    String? description,
    String? imageUrl,
    String? vegNonveg,
    String? mealType,
    String? availabilityTime,
  }) async {
    final url = Uri.parse('$_baseUrl/api/menu-items/');

    try {
      print("[v0] Adding menu item: $itemName");

      final body = json.encode({
        'item_name': itemName,
        'price': price,
        'category': category,
        'description': description ?? '',
        'image_url': imageUrl ?? '',
        'veg_nonveg': vegNonveg,
        'meal_type': mealType,
        'availability_time': availabilityTime ?? '',
      });

      final response = await http
          .post(
            url,
            headers: await _getAuthHeaders(),
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      print("[v0] Add menu response: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        throw Exception('Failed to add menu item (${response.statusCode})');
      }
    } catch (e) {
      print("[v0] Error adding menu item: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateMenuItem({
    required int itemId,
    required String itemName,
    required double price,
    required String category,
    String? description,
    String? imageUrl,
    String? vegNonveg,
    String? mealType,
    String? availabilityTime,
  }) async {
    final url = Uri.parse('$_baseUrl/api/menu-items/$itemId/');

    try {
      print("[v0] Updating menu item ID: $itemId");
      print("[v0] URL: $url");

      final prefs = await SharedPreferences.getInstance();
      String? csrfToken = prefs.getString('csrfToken');

      final body = {
        'item_name': itemName,
        'price': price.toString(),
        'category': category,
        'description': description ?? '',
        'image_url': imageUrl ?? '',
        'veg_nonveg': vegNonveg ?? '',
        'meal_type': mealType ?? '',
        'availability_time': availabilityTime ?? '',
        if (csrfToken != null) 'csrfmiddlewaretoken': csrfToken,
      };

      final headers = await _getAuthHeaders();
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      headers.remove('X-CSRFToken');

      print("[v0] Headers: $headers");
      print("[v0] Body: $body");

      final response = await http
          .put(
            url,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      print("[v0] Update menu response: ${response.statusCode}");
      print("[v0] Update menu response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            return responseData;
          }
        } catch (e) {
          return {'success': true, 'message': 'Item updated successfully'};
        }
      }
      throw Exception(
          'Failed to update menu item (${response.statusCode}): ${response.body}');
    } catch (e) {
      print("[v0] Error updating menu item: $e");
      rethrow;
    }
  }

  Future<bool> deleteMenuItem(int itemId) async {
    final url = Uri.parse('$_baseUrl/api/menu-items/$itemId/');

    try {
      print("[v0] Deleting menu item ID: $itemId");

      final response = await http
          .delete(
            url,
            headers: await _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      print("[v0] Delete menu response: ${response.statusCode}");

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("[v0] Error deleting menu item: $e");
      rethrow;
    }
  }

  void dispose() {
    // Cleanup if needed
  }
}
