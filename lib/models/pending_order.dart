// lib/models/pending_order.dart
import 'dart:convert';

List<PendingOrder> pendingOrderFromJson(String str) =>
    List<PendingOrder>.from(json.decode(str).map((x) => PendingOrder.fromJson(x)));

String pendingOrderToJson(List<PendingOrder> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class PendingOrder {
  int id;
  String orderId;  // No longer nullable, see fromJson
  String customerName;
  String customerMobile;
  List<Item> items;
  double totalPrice;
  String status;
  String paymentMethod;
  String createdAt;
  String? orderPlacedBy; // Make nullable
  String? readyAt; // Make nullable

  PendingOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerMobile,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    this.orderPlacedBy,
    this.readyAt,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    return PendingOrder(
      id: json["id"] ?? 0, // Default to 0 if null
      orderId: (json["order_id"] ?? 'N/A').toString(), // Ensure it's a string, default to 'N/A'
      customerName: json["customer_name"] ?? 'Unknown',
      customerMobile: json["customer_mobile"] ?? 'N/A',
      items: json["items"] != null
          ? List<Item>.from(json["items"].map((x) => Item.fromJson(x)))
          : [],
      totalPrice: (json["total_price"] ?? 0.0).toDouble(),
      status: json["order_status"] ?? 'Unknown',
      paymentMethod: json["payment_method"] ?? 'N/A',
      createdAt: json["created_at"] ?? DateTime.now().toIso8601String(),
      orderPlacedBy: json["order_placed_by"],
      readyAt: json["ready_time"],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_id": orderId,
        "customer_name": customerName,
        "customer_mobile": customerMobile,
        "items": List<dynamic>.from(items.map((x) => x.toJson())),
        "total_price": totalPrice,
        "order_status": status,
        "payment_method": paymentMethod,
        "created_at": createdAt,
        "order_placed_by": orderPlacedBy,
        "ready_time": readyAt,
      };
}

class Item {
  int id;
  String name;
  int quantity;
  double price;

  Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json["id"] ?? 0,
        name: json["name"] ?? 'Unknown Item',
        quantity: (json["quantity"] ?? 0).toInt(),
        price: (json["price"] ?? 0.0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "quantity": quantity,
        "price": price,
      };
}
