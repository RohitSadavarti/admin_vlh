// In: lib/services/notification_service.dart

import 'dart:convert';

import 'package:admin_vlh/services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'order_update_service.dart';

class NotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPopupShowing = false;
  String? _currentlyShowingPopupForOrderId; // <-- ADD THIS

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    await subscribeToTopic();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 [FCM] Message received: ${message.data}");

      // --- START OF MODIFIED LOGIC ---
      final messageType = message.data['type'] as String?;
      final orderSource = message.data['order_source'] as String?;

      if (messageType == 'order_update') {
        // This is a SYNC message from another device
        print("🔔 [FCM] Received order_update sync message.");
        final orderPk = message.data['order_pk'] as String?;

        // Check if we are currently showing a popup for this *exact* order
        if (_isPopupShowing && _currentlyShowingPopupForOrderId == orderPk) {
          final BuildContext? context = navigatorKey.currentContext;
          // Check if the dialog can be popped
          if (context != null && Navigator.of(context).canPop()) {
            print("🔔 [FCM] Closing matching popup for order $orderPk");
            Navigator.of(context).pop(); // This closes the dialog
          }
        }
        // *Always* notify the app to refresh its lists, even if the popup wasn't open
        OrderUpdateService().notifyOrderUpdated();
      } else if (orderSource == 'customer' && !_isPopupShowing) {
        // This is a NEW order notification
        print("🔔 [FCM] Received new customer order.");
        final orderData = {
          'id': int.tryParse(message.data['id'] ?? '0') ?? 0,
          'order_id': message.data['order_id'] ?? 'N/A',
          'customer_name': message.data['customer_name'] ?? 'Unknown',
          'total_price': message.data['total_price'] ?? '0.0',
          'items_json': message.data['items'] ?? '[]',
          'customer_phone':
              message.data['customer_phone'] ?? message.data['phone'] ?? 'N/A',
        };
        _showNewOrderPopup(orderData);
      }
      // --- END OF MODIFIED LOGIC ---
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 [FCM] App opened from notification.");
      // ...
    });
  }

  Future<void> subscribeToTopic() async {
    // ... (no changes here)
  }

  Future<void> _playNotificationRingtone() async {
    // ... (no changes here)
  }

  void _showNewOrderPopup(Map<String, dynamic> orderData) {
    _isPopupShowing = true;
    _currentlyShowingPopupForOrderId =
        orderData['id'].toString(); // <-- ADD THIS
    _playNotificationRingtone();

    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      _isPopupShowing = false;
      _currentlyShowingPopupForOrderId = null; // <-- ADD THIS
      return; // Cannot show dialog
    }

    String itemsText = "No items";
    // ... (no changes to itemsText logic) ...
    try {
      final itemsJson = orderData['items_json'] ?? '[]';
      if (itemsJson.isNotEmpty && itemsJson != '[]') {
        final List<dynamic> items = jsonDecode(itemsJson);
        if (items.isNotEmpty) {
          itemsText = items.map((item) {
            final quantity = item['quantity'] ?? 1;
            final name = item['name'] ?? 'Unknown';
            return '$quantity x $name';
          }).join('\n');
        }
      }
    } catch (e) {
      print("❌ [Notification] Error parsing items: $e");
      itemsText = "Unable to load items";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        // ... (no changes to title or content) ...
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child:
                  Text('New Customer Order!', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${orderData['order_id']} - ${orderData['customer_name']}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Ph: ${orderData['customer_phone'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Items:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(itemsText),
              const SizedBox(height: 12),
              Text(
                'Total: ₹${orderData['total_price']?.toString() ?? '0'}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('REJECT',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12)),
                  onPressed: () async {
                    await _audioPlayer.stop();
                    Navigator.of(context).pop();
                    // _isPopupShowing = false; // <-- REMOVED (handled by .then)
                    // _currentlyShowingPopupForOrderId = null; // <-- REMOVED (handled by .then)

                    try {
                      bool success =
                          await ApiService.instance.handleOrderAction(
                        orderData['id'] ?? 0, // Database ID
                        'reject',
                      );
                      // No need to notify OrderUpdateService, the backend sync will do it
                    } catch (e) {
                      print("Error rejecting order: $e");
                    }
                  },
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('ACCEPT',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12)),
                  onPressed: () async {
                    await _audioPlayer.stop();
                    Navigator.of(context).pop();
                    // _isPopupShowing = false; // <-- REMOVED (handled by .then)
                    // _currentlyShowingPopupForOrderId = null; // <-- REMOVED (handled by .then)

                    try {
                      bool success =
                          await ApiService.instance.handleOrderAction(
                        orderData['id'] ?? 0, // Database ID
                        'accept',
                      );
                      // No need to notify OrderUpdateService, the backend sync will do it
                    } catch (e) {
                      print("Error accepting order: $e");
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((_) {
      // --- ADD THIS .then() BLOCK ---
      // This executes when the dialog is popped,
      // either by the buttons OR by our new sync logic.
      _isPopupShowing = false;
      _currentlyShowingPopupForOrderId = null;
      print("🔔 Popup closed, resetting notification state.");
    });
  }
}
