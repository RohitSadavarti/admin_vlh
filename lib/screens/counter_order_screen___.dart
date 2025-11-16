// lib/screens/counter_order_screen.dart
import 'package:flutter/material.dart';

import '../models/pending_order.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class CounterOrderScreen extends StatefulWidget {
  const CounterOrderScreen({super.key});

  @override
  State<CounterOrderScreen> createState() => _CounterOrderScreenState();
}

class _CounterOrderScreenState extends State<CounterOrderScreen> {
  final ApiService _apiService = ApiService.instance;

  List<PendingOrder> _preparingOrders = [];
  List<PendingOrder> _readyOrders = [];
  List<PendingOrder> _pickedUpOrders = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadOrders();
  }

  Future<void> _checkAuthAndLoadOrders() async {
    try {
      bool isLoggedIn = _apiService.isLoggedIn();
      if (!mounted) return;

      if (!isLoggedIn) {
        _redirectToLogin();
      } else {
        await _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allOrders = await _apiService.getAllOrders();
      if (!mounted) return;

      final counterOrders =
          allOrders.where((order) => order.orderPlacedBy == 'counter').toList();

      setState(() {
        _preparingOrders = counterOrders
            .where((o) => o.status == 'pending' || o.status == 'preparing')
            .toList();
        _readyOrders = counterOrders.where((o) => o.status == 'ready').toList();
        _pickedUpOrders = counterOrders
            .where((o) => o.status == 'picked_up' || o.status == 'completed')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Authentication failed')) {
        _redirectToLogin();
      } else {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    _apiService.logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired. Please log in again.')),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _onOrderAction(int orderDbId, String action) async {
    try {
      final result = await _apiService.handleOrderAction(orderDbId, action);
      bool success = result['success'] == true;
      if (!mounted) return;

      String successMessage;
      switch (action) {
        case 'mark_ready':
          successMessage = 'Order Marked as Ready';
          break;
        case 'mark_picked_up':
          successMessage = 'Order Marked as Picked Up';
          break;
        default:
          successMessage = 'Action completed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('$successMessage ${success ? 'successfully' : 'failed'}'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        await _loadOrders();
      }
    } catch (e) {
      // ... error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Orders'),
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildTabView();
            } else {
              return _buildRowLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildRowLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _buildOrderColumn(
                title: 'Preparing',
                orders: _preparingOrders,
                icon: Icons.kitchen_rounded,
                color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildOrderColumn(
                title: 'Ready',
                orders: _readyOrders,
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildOrderColumn(
                title: 'Picked Up',
                orders: _pickedUpOrders,
                icon: Icons.shopping_bag_rounded,
                color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildTabView() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: 'Preparing (${_preparingOrders.length})'),
              Tab(text: 'Ready (${_readyOrders.length})'),
              Tab(text: 'Picked Up (${_pickedUpOrders.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(_preparingOrders),
                _buildOrderList(_readyOrders),
                _buildOrderList(_pickedUpOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderColumn({
    required String title,
    required List<PendingOrder> orders,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('$title (${orders.length})',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8)),
            ),
            child: _buildOrderList(orders),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<PendingOrder> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('No orders in this category.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  List<Widget> _buildActionButtons(PendingOrder order) {
    switch (order.status.toLowerCase()) {
      case 'pending':
      case 'preparing':
        return [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _onOrderAction(order.id, 'mark_ready'),
              child: const Text('Mark Ready', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ];
      case 'ready':
        return [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _onOrderAction(order.id, 'mark_picked_up'),
              child: const Text('Mark Picked Up', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildOrderCard(PendingOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(order.customerName),
            Text(order.customerMobile),
            const Divider(),
            ...order.items
                .map((item) => Text('${item.quantity}x ${item.name}')),
            const Divider(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('₹${order.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: _buildActionButtons(order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
