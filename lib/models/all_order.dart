class AllOrder {
  final int id;
  final String orderId;
  final String customerName;
  final String customerMobile;
  final String createdAt;
  final double totalPrice;
  final String orderStatus; // Added field for order status
  final String orderPlacedBy; // Added field for order_placed_by
  final List<OrderItem> items;

  AllOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerMobile,
    required this.createdAt,
    required this.totalPrice,
    required this.orderStatus,
    required this.orderPlacedBy,
    required this.items,
  });

  factory AllOrder.fromJson(Map<String, dynamic> json) {
    try {
      return AllOrder(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        orderId: json['order_id']?.toString() ?? json['orderId']?.toString() ?? '',
        customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? 'Unknown',
        customerMobile: json['customer_mobile']?.toString() ?? json['customerMobile']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
        totalPrice: _parseDouble(json['total_price'] ?? json['totalPrice'] ?? 0),
        orderStatus: json['order_status']?.toString().toLowerCase() ?? 'open',
        orderPlacedBy: json['order_placed_by']?.toString().toLowerCase() ?? 'counter',
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => OrderItem.fromJson(item))
                .toList() ??
            [],
      );
    } catch (e) {
      print('❌ Error parsing AllOrder: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'created_at': createdAt,
      'total_price': totalPrice,
      'order_status': orderStatus,
      'order_placed_by': orderPlacedBy,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderItem {
  final int id;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      return OrderItem(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        name: json['name']?.toString() ?? json['item_name']?.toString() ?? 'Unknown Item',
        quantity: json['quantity'] is int
            ? json['quantity']
            : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
        price: _parseDouble(json['price'] ?? json['item_price'] ?? 0),
      );
    } catch (e) {
      print('❌ Error parsing OrderItem: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}
