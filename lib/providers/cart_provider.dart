// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};

  // --- GETTERS ---
  // Use this to get the items as a Map
  Map<int, CartItem> get items => {..._items};

  // Use this to get the items as a List for ListViews
  List<CartItem> get itemsAsList => _items.values.toList();

  // Use this to get the total number of items
  int get itemCount => _items.length;

  // Use this to check if the cart is empty
  bool get isEmpty => _items.isEmpty;

  // This is the getter that was missing
  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.item.price * cartItem.quantity;
    });
    return total;
  }

  // Get quantity for a specific item
  int getQuantity(int itemId) {
    return _items.containsKey(itemId) ? _items[itemId]!.quantity : 0;
  }

  // --- METHODS ---
  void addItem(MenuItem item) {
    if (_items.containsKey(item.id)) {
      // just increase quantity
      _items.update(
        item.id,
        (existingCartItem) => CartItem(
          item: existingCartItem.item,
          quantity: existingCartItem.quantity + 1,
        ),
      );
    } else {
      // add a new item
      _items.putIfAbsent(
        item.id,
        () => CartItem(item: item, quantity: 1),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(int itemId) {
    if (!_items.containsKey(itemId)) {
      return;
    }
    if (_items[itemId]!.quantity > 1) {
      _items.update(
        itemId,
        (existingCartItem) => CartItem(
          item: existingCartItem.item,
          quantity: existingCartItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(itemId);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
