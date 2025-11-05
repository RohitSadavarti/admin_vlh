import 'cart_item.dart'; // Assuming you have cart_item.dart

class OrderDetails {
  final String orderId;
  final String customerName;
  final String customerMobile;
  final List<CartItem> items;
  final double total;
  final String paymentMethod;
  final DateTime timestamp;

  OrderDetails({
    required this.orderId,
    required this.customerName,
    required this.customerMobile,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.timestamp,
  });
}
