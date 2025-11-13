class MenuItem {
  final int id;
  final String name;
  final double price;
  final String category;
  final String? description;
  final String? imageUrl;
  final String? vegNonveg;
  final String? mealType;
  final String? availabilityTime;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description,
    this.imageUrl,
    this.vegNonveg,
    this.mealType,
    this.availabilityTime,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['item_name'],
      // Handle price that might be int or double
      price: (json['price'] as num).toDouble(),
      category: json['category'],
      description: json['description'],
      imageUrl: json['image_url'],
      vegNonveg: json['veg_nonveg'],
      mealType: json['meal_type'],
      availabilityTime: json['availability_time'],
    );
  }

  // Method to convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': name,
      'price': price,
      'category': category,
      'description': description,
      'image_url': imageUrl,
      'veg_nonveg': vegNonveg,
      'meal_type': mealType,
      'availability_time': availabilityTime,
    };
  }
}
