// lib/models/order_details.dart
import 'cart_item.dart';

class OrderDetails {
  final String orderId;
  final String customerName;
  final String customerMobile;
  final List<CartItem> items;
  final String paymentMethod;
  final double totalPrice; // ADDED
  final DateTime orderDate;

  OrderDetails({
    required this.orderId,
    required this.customerName,
    required this.customerMobile,
    required this.items,
    required this.paymentMethod,
    required this.totalPrice, // ADDED
    DateTime? orderDate,
  }) : orderDate = orderDate ?? DateTime.now();

  String get formattedTotal {
    return '₹${totalPrice.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${orderDate.day}/${orderDate.month}/${orderDate.year} ${orderDate.hour}:${orderDate.minute.toString().padLeft(2, '0')}';
  }
}
