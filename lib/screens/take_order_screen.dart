// lib/screens/take_order_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_app_bar.dart'; // Import ProfileAppBar
import '../widgets/quantity_control.dart';

class TakeOrderScreen extends StatefulWidget {
  const TakeOrderScreen({super.key});

  @override
  State<TakeOrderScreen> createState() => _TakeOrderScreenState();
}

class _TakeOrderScreenState extends State<TakeOrderScreen> {
  final ApiService _apiService = ApiService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<MenuItem> _allMenuItems = [];
  List<MenuItem> _filteredMenuItems = [];
  List<String> _categories = ['All Categories'];
  String _selectedCategory = 'All Categories';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenu();
    _searchController.addListener(_filterMenu);
  }

  Future<void> _fetchMenu() async {
    if (!mounted) return;
    try {
      final items = await _apiService.fetchMenuItems();
      if (!mounted) return;

      final categories = items.map((item) => item.category).toSet().toList();
      categories.sort();

      setState(() {
        _allMenuItems = items;
        _filteredMenuItems = items;
        _categories = ['All Categories', ...categories];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load menu: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _filterMenu() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredMenuItems = _allMenuItems.where((item) {
        final matchesCategory = _selectedCategory == 'All Categories' ||
            item.category == _selectedCategory;
        final matchesSearch = item.name.toLowerCase().contains(searchQuery);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMenu);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: ProfileAppBar(
        title: 'Take Order (POS)', // Changed from Text('...') to String
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return Badge.count(
                count: cart.itemCount,
                isLabelVisible: !cart.isEmpty,
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'View Cart',
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterControls(theme),
                Expanded(
                  child: _filteredMenuItems.isEmpty
                      ? const Center(child: Text('No menu items found.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                1, // Changed from 2 to 1 for single column layout
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.8,
                          ),
                          itemCount: _filteredMenuItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredMenuItems[index];
                            return _buildMenuItemCard(item, theme);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.isEmpty) {
            return Container();
          }
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            label: Text('View Cart (₹${cart.totalAmount.toStringAsFixed(2)})'),
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        onTap: (index) {},
      ),
    );
  }

  Widget _buildFilterControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                    _filterMenu();
                  });
                }
              },
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item, ThemeData theme) {
    final textTheme = theme.textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.name,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${item.price.toStringAsFixed(2)}',
                    style: textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 36, // Ensure consistent height
                  child: QuantityControl(item: item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
