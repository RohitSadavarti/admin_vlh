// lib/services/notification_service.dart
import 'dart:convert';

import 'package:admin_vlh/services/api_service.dart'; // Your ApiService
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// This class will hold the logic
class NotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPopupShowing = false;

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    // 1. Listen for messages when the app is OPEN
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          "🔔 [FCM] Foreground message received: ${message.notification?.title}");

      final String orderSource = message.data['order_source'] ?? '';

      // --- THIS IS THE KEY LOGIC ---
      // Only show popup if it's a 'customer' order and no popup is already showing
      if (orderSource == 'customer' && !_isPopupShowing) {
        // Parse the order data
        final orderData = {
          'id': int.tryParse(message.data['id'] ?? '0') ?? 0,
          'order_id': message.data['order_id'] ?? 'N/A',
          'customer_name': message.data['customer_name'] ?? 'Unknown',
          'total_price': message.data['total_price'] ?? '0.0',
          'items_json': message.data['items'] ?? '[]'
        };
        _showNewOrderPopup(orderData);
      }
    });

    // 2. Handle messages when the app is in the BACKGROUND or TERMINATED
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 [FCM] App opened from notification.");
      // Here, you could navigate to the order screen,
      // but the popup is more important for foreground.
    });
  }

  // --- The Popup and Ringtone Logic ---
  void _showNewOrderPopup(Map<String, dynamic> orderData) async {
    _isPopupShowing = true;
    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) {
      _isPopupShowing = false;
      return; // Cannot show dialog
    }

    // Start playing ringtone on loop
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(
          AssetSource('sounds/ringtone.mp3')); // Make sure you add this file
    } catch (e) {
      print("Error playing sound: $e");
    }

    // --- Show the PERSISTENT popup ---
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        // Simple parsing for display
        List<dynamic> items = jsonDecode(orderData['items_json']);
        String itemsSummary = items
            .map((item) => "${item['quantity']}x ${item['name']}")
            .join('\n');

        return WillPopScope(
          onWillPop: () async => false, // Prevents dismissing with back button
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text('New Customer Order!'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${orderData['order_id']} - ${orderData['customer_name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Total: ₹${orderData['total_price']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 20),
                  Text(itemsSummary),
                ],
              ),
            ),
            actions: <Widget>[
              // --- REJECT BUTTON ---
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('REJECT',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _audioPlayer.stop(); // Stop ringtone
                  Navigator.of(dialogContext).pop(); // Close dialog
                  _isPopupShowing = false;

                  // Call your API
                  try {
                    await ApiService.instance.handleOrderAction(
                      orderData['id'],
                      'reject', // Your API accepts 'reject'
                    );
                  } catch (e) {
                    // Show an error snackbar if it fails
                  }
                },
              ),
              // --- ACCEPT BUTTON ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('ACCEPT',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _audioPlayer.stop(); // Stop ringtone
                  Navigator.of(dialogContext).pop(); // Close dialog
                  _isPopupShowing = false;

                  // Call your API
                  try {
                    await ApiService.instance.handleOrderAction(
                      orderData['id'],
                      'accept', // Your API accepts 'accept'
                    );
                  } catch (e) {
                    // Show an error snackbar if it fails
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
