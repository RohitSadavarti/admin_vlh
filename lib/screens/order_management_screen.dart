import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pending_order.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Online Orders State
  List<PendingOrder>? _preparingOrders;
  List<PendingOrder>? _readyOrders;
  List<PendingOrder>? _pickedUpOrders;

  // Counter Orders State
  List<PendingOrder>? _counterOrders;
  List<PendingOrder>? _filteredCounterOrders;

  bool _isLoading = true;
  String? _errorMessage;

  // Filters for Counter Orders
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime.now();
    _searchController.addListener(_filterCounterOrders);
    _checkAuthAndLoadOrders();
  }

  Future<void> _checkAuthAndLoadOrders() async {
    try {
      bool isLoggedIn = await _apiService.isLoggedIn();

      if (!isLoggedIn) {
        if (mounted) {
          _redirectToLogin();
        }
        return;
      }

      await _loadAllOrders();
    } catch (e) {
      print("Error in _checkAuthAndLoadOrders: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadAllOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allOrders = await _apiService.getAllOrders();

      // Filter online orders
      final online = allOrders
          .where((order) =>
              order.orderPlacedBy == 'customer' &&
              (order.orderStatus == 'open' ||
                  order.orderStatus == 'ready' ||
                  order.orderStatus == 'pickedup'))
          .toList();

      // Filter counter orders
      final counter =
          allOrders.where((order) => order.orderPlacedBy == 'counter').toList();

      if (mounted) {
        setState(() {
          _preparingOrders =
              online.where((order) => order.orderStatus == 'open').toList();
          _readyOrders =
              online.where((order) => order.orderStatus == 'ready').toList();
          _pickedUpOrders =
              online.where((order) => order.orderStatus == 'pickedup').toList();

          _counterOrders = counter;
          _filterCounterOrders();

          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading orders: $e");

      if (mounted) {
        if (e.toString().contains('Authentication failed') ||
            e.toString().contains('Session expired')) {
          _redirectToLogin();
        } else {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _filterCounterOrders() {
    if (_counterOrders == null) return;

    List<PendingOrder> filtered = _counterOrders!;

    if (_selectedDate != null) {
      filtered = filtered.where((order) {
        try {
          DateTime orderDate = DateTime.parse(order.createdAt).toLocal();
          return orderDate.year == _selectedDate!.year &&
              orderDate.month == _selectedDate!.month &&
              orderDate.day == _selectedDate!.day;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        return order.orderId.toLowerCase().contains(query) ||
            order.customerName.toLowerCase().contains(query) ||
            order.customerMobile.contains(query);
      }).toList();
    }

    setState(() {
      _filteredCounterOrders = filtered;
    });
  }

  void _redirectToLogin() {
    _apiService.logout();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      bool success = await _apiService.updateOrderStatus(orderId, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order updated to $newStatus ${success ? 'successfully' : 'failed'}',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        if (success) {
          await _loadAllOrders();
        }
      }
    } catch (e) {
      print("Error updating order status: $e");

      if (mounted) {
        if (e.toString().contains('Authentication failed') ||
            e.toString().contains('Session expired')) {
          _redirectToLogin();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Online Orders'),
            Tab(text: 'Counter Orders'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllOrders,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading orders...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOnlineOrdersTab(),
                _buildCounterOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildOnlineOrdersTab() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildOrderSection(
          title: 'Preparing Orders',
          orders: _preparingOrders ?? [],
          statusColor: Colors.amber,
          newStatus: 'ready',
        ),
        _buildOrderSection(
          title: 'Ready for Pickup',
          orders: _readyOrders ?? [],
          statusColor: Colors.blue,
          newStatus: 'pickedup',
        ),
        _buildOrderSection(
          title: 'Picked Up',
          orders: _pickedUpOrders ?? [],
          statusColor: Colors.green,
          newStatus: null, // No action for picked up
        ),
      ],
    );
  }

  Widget _buildCounterOrdersTab() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Date picker
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _selectedDate != null
                      ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                      : 'Select Date',
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _selectedDate = picked;
                    });
                    _filterCounterOrders();
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Order ID, Name, or Mobile...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Counter orders list
        Expanded(
          child:
              _filteredCounterOrders == null || _filteredCounterOrders!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No counter orders found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            onPressed: _loadAllOrders,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredCounterOrders!.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(
                          _filteredCounterOrders![index],
                          showStatusButton: true,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOrderSection({
    required String title,
    required List<PendingOrder> orders,
    required Color statusColor,
    String? newStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Text(
                '$title (${orders.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          orders.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No orders in $title',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : Column(
                  children: orders
                      .map((order) => _buildOrderCard(
                            order,
                            showStatusButton: newStatus != null,
                            nextStatus: newStatus,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    PendingOrder order, {
    bool showStatusButton = false,
    String? nextStatus,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.orderId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.orderStatus.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  order.customerMobile,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.createdAt,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            const Text(
              'Items:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${item.quantity}x ${item.name} - ₹${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
            const Divider(height: 16),
            if (showStatusButton && nextStatus != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '₹${order.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        'Mark ${nextStatus == 'ready' ? 'Ready' : 'Picked Up'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _updateOrderStatus(order.id, nextStatus),
                    ),
                  ),
                ],
              )
            else
              Text(
                '₹${order.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadAllOrders,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
