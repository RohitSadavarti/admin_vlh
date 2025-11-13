// lib/widgets/quantity_control.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../providers/cart_provider.dart';

class QuantityControl extends StatelessWidget {
  final MenuItem item;

  const QuantityControl({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Use Consumer to get the cart and rebuild on changes
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final int quantity = cart.getQuantity(item.id);

        if (quantity == 0) {
          return ElevatedButton(
            onPressed: () {
              cart.addItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Add'),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  cart.removeSingleItem(item.id);
                },
                color: Colors.red,
              ),
              Text(
                quantity.toString(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  cart.addItem(item);
                },
                color: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }
}
