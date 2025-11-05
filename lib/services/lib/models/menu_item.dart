class MenuItem {
  final int id;
  final String name;
  final double price;
  final String category;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['item_name'],
      // Handle price that might be int or double
      price: (json['price'] as num).toDouble(), 
      category: json['category'],
    );
  }
}
