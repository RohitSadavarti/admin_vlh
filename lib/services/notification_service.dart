// lib/services/notification_service.dart
import 'dart:convert';

import 'package:admin_vlh/services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Make sure this is imported
import 'package:flutter/material.dart';

import 'order_update_service.dart'; // <-- IMPORTED THE NEW SERVICE

class NotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPopupShowing = false;

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    // 1. Request permission (especially for iOS)
    await FirebaseMessaging.instance.requestPermission();

    // --- 2. ADD THIS FUNCTION CALL ---
    await subscribeToTopic();
    // --------------------------------

    // 3. Listen for messages when the app is OPEN
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // --- ADD THIS PRINT STATEMENT FOR DEBUGGING ---
      print("🔔 [FCM] Message received: ${message.data}");
      // ------------------------------------------------

      final String orderSource = message.data['order_source'] ?? '';

      // --- ADD THIS PRINT STATEMENT FOR DEBUGGING ---
      print("🔔 [FCM] Order Source: $orderSource");
      // ------------------------------------------------

      if (orderSource == 'customer' && !_isPopupShowing) {
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
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 [FCM] App opened from notification.");
      // Here, you could navigate to the order screen,
      // but the popup is more important for foreground.
    });
  }

  // --- 4. ADD THIS NEW FUNCTION ---
  Future<void> subscribeToTopic() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('new_orders');
      print("✅ [FCM] Subscribed to 'new_orders' topic successfully.");
    } catch (e) {
      print("❌ [FCM] FAILED to subscribe to topic: $e");
    }
  }
  // --------------------------------

  Future<void> _playNotificationRingtone() async {
    try {
      // Try to play from assets first
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      print("✅ [Audio] Ringtone playing from assets");
    } catch (e) {
      print("⚠️ [Audio] Could not play asset sound: $e");
      try {
        // Fallback: Use system notification sound
        await _audioPlayer.play(AssetSource('sounds/default_notification.wav'));
        print("✅ [Audio] Playing fallback notification sound");
      } catch (e2) {
        print("❌ [Audio] Could not play any notification sound: $e2");
      }
    }
  }

  // --- The Popup and Ringtone Logic ---
  void _showNewOrderPopup(Map<String, dynamic> orderData) {
    _isPopupShowing = true;

    _playNotificationRingtone();

    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      _isPopupShowing = false;
      return; // Cannot show dialog
    }

    String itemsText = "No items";
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
                    _isPopupShowing = false;

                    try {
                      bool success =
                          await ApiService.instance.handleOrderAction(
                        orderData['id'] ?? 0, // Database ID
                        'reject',
                      );
                      if (success) {
                        OrderUpdateService().notifyOrderUpdated();
                      }
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
                    _isPopupShowing = false;

                    try {
                      bool success =
                          await ApiService.instance.handleOrderAction(
                        orderData['id'] ?? 0, // Database ID
                        'accept',
                      );
                      if (success) {
                        OrderUpdateService().notifyOrderUpdated();
                      }
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
    );
  }
}
