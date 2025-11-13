// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Ensure all your import paths are correct
import '../models/cart_item.dart';
import '../models/order_details.dart'; // Needed for invoice screen data
import '../providers/cart_provider.dart';
import '../screens/invoice_screen.dart'; // Your REAL InvoiceScreen
import '../services/api_service.dart';
import '../widgets/quantity_control.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Controllers for text fields
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  // Payment method options and state
  final _paymentMethods = ['Cash', 'UPI', 'Card']; // Customize as needed
  String _selectedPaymentMethod = 'Cash'; // Default selection

  // Loading state for placing order
  bool _isPlacingOrder = false;

  // Instance of your API service
  final _apiService = ApiService();

  // Function to handle the place order logic
  Future<void> _handlePlaceOrder() async {
    final cart = context.read<CartProvider>();

    // --- Input Validation ---
    final String customerName = _nameController.text.trim();
    final String customerMobile = _mobileController.text.trim();

    if (customerName.isEmpty || customerMobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter customer name and mobile.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(customerMobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit mobile number.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Your cart is empty.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    // --- End Validation ---

    if (mounted) {
      setState(() {
        _isPlacingOrder = true;
      });
    }

    try {
      final List<CartItem> currentCartItems = cart.itemsAsList;
      final double currentTotalAmount = cart.totalAmount;

      print('[v0] Attempting to place order with name: $customerName, mobile: $customerMobile, items: ${currentCartItems.length}, total: $currentTotalAmount');
      
      final result = await _apiService.placeOrder(
        customerName,
        customerMobile,
        _selectedPaymentMethod.toLowerCase(),
        currentCartItems,
        currentTotalAmount,
      );

      final String orderId = result['order_id']?.toString() ?? result['id']?.toString() ?? 'N/A';
      print('[v0] Order placed successfully! Backend Order ID: $orderId');

      final orderDetails = OrderDetails(
        orderId: orderId,
        customerName: customerName,
        customerMobile: customerMobile,
        items: currentCartItems,
        paymentMethod: _selectedPaymentMethod,
        totalPrice: currentTotalAmount,
      );

      cart.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceScreen(orderDetails: orderDetails),
          ),
        );
      }
    } catch (e) {
      print('[v0] Error placing order in UI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  // --- build() method ---
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (ctx, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Confirm Order'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear Cart',
                onPressed: cart.isEmpty
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear Cart?'),
                            content:
                                const Text('Remove all items from the cart?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('No'),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                              TextButton(
                                child: const Text('Yes',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  cart.clearCart(); // Use correct method
                                  Navigator.of(ctx).pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- Customer Details Section ---
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Customer Details",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Customer Name*',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0)),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number*',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0)),
                            prefixIcon: const Icon(Icons.phone_android),
                            counterText: "",
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Payment Method ---
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedPaymentMethod = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),

                // --- Cart Items Header ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Items in Cart (${cart.itemCount})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                // --- Cart Items List ---
                cart.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              'Your cart is empty. Add items from the menu.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cart.itemCount,
                        itemBuilder: (ctx, i) {
                          final cartItem = cart.itemsAsList[i];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: FittedBox(
                                    child: Text(
                                        '₹${cartItem.item.price.toStringAsFixed(0)}'),
                                  ),
                                ),
                              ),
                              title: Text(cartItem.item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                  'Total: ₹${(cartItem.item.price * cartItem.quantity).toStringAsFixed(2)}'),
                              trailing: QuantityControl(
                                // Use item parameter
                                item: cartItem.item,
                              ),
                            ),
                          );
                        },
                      ),

                const SizedBox(height: 20),

                // --- Order Summary Card (Total Amount) ---
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Grand Total',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Chip(
                          label: Text(
                            '₹${cart.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- Place Order Button ---
                ElevatedButton.icon(
                  icon: _isPlacingOrder
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: (_isPlacingOrder || cart.isEmpty)
                      ? null
                      : _handlePlaceOrder,
                  label: Text(
                    _isPlacingOrder
                        ? 'Placing Order...'
                        : 'Confirm and Place Order',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dispose controllers
  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}
