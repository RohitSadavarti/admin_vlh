import 'dart:async'; // Correct import

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/order_details.dart';
import '../models/pending_order.dart';
import '../screens/invoice_screen.dart';
import '../services/api_service.dart';
import '../services/order_update_service.dart'; // <-- MODIFICATION: Import the new service
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_app_bar.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService.instance;
  late TabController _tabController;
  late Timer _timer;

  // <-- MODIFICATION: Add subscription variable
  late StreamSubscription _orderUpdateSubscription;

  // --- State for Online Orders ---
  final TextEditingController _onlineSearchController = TextEditingController();
  List<PendingOrder> _allOnlineOrders = [];
  List<PendingOrder> _filteredOnlineOrders = [];
  String _onlineSelectedFilter = 'this_month'; // Default to this_month
  DateTimeRange? _onlineCustomDateRange;
  String _onlineSearchQuery = '';

  // --- State for Counter Orders ---
  final TextEditingController _counterSearchController =
      TextEditingController();
  List<PendingOrder> _allCounterOrders = [];
  List<PendingOrder> _filteredCounterOrders = [];
  String _counterSelectedFilter = 'this_month'; // Default to this_month
  DateTimeRange? _counterCustomDateRange;
  String _counterSearchQuery = '';

  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Rebuild every second to update timers
      }
    });
    _onlineSearchController.addListener(_onOnlineSearchChanged);
    _counterSearchController.addListener(_onCounterSearchChanged);

    // <-- MODIFICATION: Start listening for order updates
    _orderUpdateSubscription = OrderUpdateService().stream.listen((_) {
      print("Refreshing AdminOrderScreen due to order update...");
      if (mounted) {
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    _onlineSearchController.removeListener(_onOnlineSearchChanged);
    _onlineSearchController.dispose();
    _counterSearchController.removeListener(_onCounterSearchChanged);
    _counterSearchController.dispose();
    _orderUpdateSubscription.cancel(); // <-- MODIFICATION: Cancel the listener
    super.dispose();
  }

  // This function now calls setState only ONCE at the end
  Future<void> _loadOrders() async {
    if (!mounted) return;

    if (!_hasLoadedOnce) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      //
      // Load 'this_month' by default
      //
      final allOrders = await _apiService.fetchOrders(dateFilter: 'this_month');
      if (!mounted) return;

      // Set the base lists
      _allOnlineOrders = allOrders
          .where((o) => o.orderPlacedBy?.toLowerCase() == 'customer')
          .toList();

      _allCounterOrders = allOrders
          .where((o) => o.orderPlacedBy?.toLowerCase() == 'counter')
          .toList();

      // Run the filter logic *before* setState
      _applyOnlineFilter();
      _applyCounterFilter();

      // Call setState ONCE with the final state
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  // Listeners now call setState directly
  void _onOnlineSearchChanged() {
    setState(() {
      _onlineSearchQuery = _onlineSearchController.text.toLowerCase();
      _applyOnlineFilter(); // Apply filter within setState
    });
  }

  void _onCounterSearchChanged() {
    setState(() {
      _counterSearchQuery = _counterSearchController.text.toLowerCase();
      _applyCounterFilter(); // Apply filter within setState
    });
  }

  // This function does NOT call setState
  void _applyOnlineFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_onlineSelectedFilter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'this_week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case 'this_month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
      case 'this_year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1);
        break;
      case 'custom':
        if (_onlineCustomDateRange != null) {
          startDate = _onlineCustomDateRange!.start;
          endDate = _onlineCustomDateRange!.end.add(const Duration(days: 1));
        } else {
          _filteredOnlineOrders = _allOnlineOrders;
          return;
        }
        break;
      default:
        // Default to 'this_month'
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
    }

    _filteredOnlineOrders = _allOnlineOrders.where((order) {
      try {
        final orderDate = DateTime.parse(order.createdAt).toLocal();
        final matchesDate =
            !orderDate.isBefore(startDate) && orderDate.isBefore(endDate);

        if (!matchesDate) return false;
        final placedBy = order.orderPlacedBy?.toLowerCase() ?? '';
        if (placedBy != 'customer') {
          return false;
        }

        // 2. Check for only the active statuses you requested
        // This will filter out 'open', 'rejected', and 'completed'
        final status = order.status.toLowerCase();
        final isActiveStatus = status == 'open' ||
            status == 'preparing' ||
            status == 'ready' ||
            status == 'pickedup';

        if (!isActiveStatus) {
          return false;
        }

        // Apply search filter
        if (_onlineSearchQuery.isEmpty) {
          return true; // Already matches date
        }

        return order.orderId.toLowerCase().contains(_onlineSearchQuery) ||
            order.customerName.toLowerCase().contains(_onlineSearchQuery) ||
            order.customerMobile.contains(_onlineSearchQuery) ||
            order.items.any(
                (item) => item.name.toLowerCase().contains(_onlineSearchQuery));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  // This function does NOT call setState
  void _applyCounterFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_counterSelectedFilter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'this_week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case 'this_month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
      case 'this_year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1);
        break;
      case 'custom':
        if (_counterCustomDateRange != null) {
          startDate = _counterCustomDateRange!.start;
          endDate = _counterCustomDateRange!.end.add(const Duration(days: 1));
        } else {
          _filteredCounterOrders = _allCounterOrders;
          return;
        }
        break;
      default:
        // Default to 'this_month'
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
    }

    _filteredCounterOrders = _allCounterOrders.where((order) {
      try {
        final orderDate = DateTime.parse(order.createdAt).toLocal();
        final matchesDate =
            !orderDate.isBefore(startDate) && orderDate.isBefore(endDate);

        if (!matchesDate) return false;

        // Apply search filter
        if (_counterSearchQuery.isEmpty) {
          return true; // Already matches date
        }

        return order.orderId.toLowerCase().contains(_counterSearchQuery) ||
            order.customerName.toLowerCase().contains(_counterSearchQuery) ||
            order.customerMobile.contains(_counterSearchQuery) ||
            order.items.any((item) =>
                item.name.toLowerCase().contains(_counterSearchQuery));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<void> _onOrderAction(int orderDbId, String action) async {
    try {
      // Correctly awaits a bool
      final bool success =
          await _apiService.updateOrderStatus(orderDbId, action);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Order status updated successfully'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ));
        await _loadOrders(); // Refresh all data
      } else {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  void _markOrderReady(int orderDbId) async {
    try {
      final success = await _apiService.updateOrderStatus(orderDbId, 'ready');
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order marked as ready'),
          backgroundColor: Colors.green,
        ));
        await _loadOrders();
      } else {
        throw Exception('Failed to mark order as ready');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  void _markOrderPickedUp(int orderDbId) async {
    try {
      final success =
          await _apiService.updateOrderStatus(orderDbId, 'pickedup');
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order marked as picked up'),
          backgroundColor: Colors.green,
        ));
        await _loadOrders();
      } else {
        throw Exception('Failed to mark order as picked up');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  void _viewInvoice(PendingOrder order) {
    final orderDetails = OrderDetails(
      orderId: order.orderId,
      customerName: order.customerName,
      customerMobile: order.customerMobile,
      items: order.items
          .map((e) => CartItem(
              item: MenuItem(
                  id: e.id, name: e.name, price: e.price, category: ''),
              quantity: e.quantity))
          .toList(),
      paymentMethod: order.paymentMethod,
      totalPrice: order.totalPrice,
    );
    Navigator.pushNamed(context, InvoiceScreen.routeName,
        arguments: orderDetails);
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'pickedup' || statusLower == 'completed') {
      return Colors.blueGrey.shade400;
    }
    if (statusLower == 'ready') {
      return Theme.of(context).colorScheme.secondary;
    }
    if (statusLower == 'open' || statusLower == 'preparing') {
      return Colors.amber.shade700;
    }
    return Theme.of(context).colorScheme.error;
  }

  IconData _getStatusIcon(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'pickedup' || statusLower == 'completed') {
      return Icons.shopping_bag_rounded;
    }
    if (statusLower == 'ready') {
      return Icons.check_circle_outline_rounded;
    }
    if (statusLower == 'open' || statusLower == 'preparing') {
      return Icons.kitchen_rounded;
    }
    return Icons.error_outline_rounded;
  }

  // Display text for Online Filter
  String _getOnlineFilterDisplayText() {
    switch (_onlineSelectedFilter) {
      case 'today':
        return 'Today';
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return 'This Month';
      case 'this_year':
        return 'This Year';
      case 'custom':
        if (_onlineCustomDateRange != null) {
          final formatter = DateFormat('MMM dd');
          return '${formatter.format(_onlineCustomDateRange!.start)} - ${formatter.format(_onlineCustomDateRange!.end)}';
        }
        return 'Custom Range';
      default:
        return 'This Month';
    }
  }

  // Display text for Counter Filter
  String _getCounterFilterDisplayText() {
    switch (_counterSelectedFilter) {
      case 'today':
        return 'Today';
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return 'This Month';
      case 'this_year':
        return 'This Year';
      case 'custom':
        if (_counterCustomDateRange != null) {
          final formatter = DateFormat('MMM dd');
          return '${formatter.format(_counterCustomDateRange!.start)} - ${formatter.format(_counterCustomDateRange!.end)}';
        }
        return 'Custom Range';
      default:
        return 'This Month';
    }
  }

  // Date picker for Online Filter (calls setState)
  void _showOnlineCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _onlineCustomDateRange,
    );
    if (picked != null) {
      setState(() {
        _onlineCustomDateRange = picked;
        _onlineSelectedFilter = 'custom';
        _applyOnlineFilter(); // Apply online filter
      });
    }
  }

  // Date picker for Counter Filter (calls setState)
  void _showCounterCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _counterCustomDateRange,
    );
    if (picked != null) {
      setState(() {
        _counterCustomDateRange = picked;
        _counterSelectedFilter = 'custom';
        _applyCounterFilter(); // Apply counter filter
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasLoadedOnce) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading orders...',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && !_hasLoadedOnce) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Failed to load orders',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                    onPressed: _loadOrders,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    // Split *filtered* online orders by status
    final preparingOrders = _filteredOnlineOrders.where((o) {
      final status = o.status.toLowerCase();
      return status == 'open' || status == 'preparing';
    }) // Requirement: 'open' only
        .toList();

    final readyOrders = _filteredOnlineOrders
        .where((o) =>
            o.status.toLowerCase() == 'ready') // Requirement: 'ready' only
        .toList();

    final pickedUpOrders = _filteredOnlineOrders
        .where((o) =>
            o.status.toLowerCase() ==
            'pickedup') // Requirement: 'pickedup' only
        .toList();

    // Use the count of *filtered* orders for the tab
    final onlineOrderCount = _filteredOnlineOrders.length;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + kToolbarHeight),
        child: Column(
          children: [
            ProfileAppBar(
              title: 'Order Management',
              onRefresh: _loadOrders,
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.7),
              tabs: [
                Tab(
                    child: Text(
                        'Online Orders (${_filteredOnlineOrders.length})')),
                Tab(
                    child: Text(
                        'Counter Orders (${_filteredCounterOrders.length})')),
              ],
            ),
          ],
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
        ],
        body: _buildBody(preparingOrders, readyOrders, pickedUpOrders),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {},
      ),
    );
  }

  Widget _buildBody(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    if (_errorMessage != null && _hasLoadedOnce) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to refresh orders',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return TabBarView(controller: _tabController, children: [
      RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildOnlineOrdersView(
            preparingOrders, readyOrders, pickedUpOrders),
      ),
      RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildCounterOrdersView(_filteredCounterOrders), // Pass filtered
      ),
    ]);
  }

  // Build Online Orders View with Filters
  Widget _buildOnlineOrdersView(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    return Column(
      children: [
        // Search Bar and Date Filter for Online Orders
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _onlineSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by order ID, name, phone, or item...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _onlineSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _onlineSearchController.clear();
                            // Manually trigger the listener logic
                            _onOnlineSearchChanged();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Date Filter
              Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<String>(
                      // Popup now calls setState
                      onSelected: (value) {
                        if (value == 'custom') {
                          _showOnlineCustomDatePicker();
                        } else {
                          setState(() {
                            _onlineSelectedFilter = value;
                            _applyOnlineFilter();
                          });
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'today', child: Text('Today')),
                        const PopupMenuItem(
                            value: 'this_week', child: Text('This Week')),
                        const PopupMenuItem(
                            value: 'this_month', child: Text('This Month')),
                        const PopupMenuItem(
                            value: 'this_year', child: Text('This Year')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'custom', child: Text('Custom Range')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(_getOnlineFilterDisplayText()),
                              ],
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // End of Filters
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            if (_filteredOnlineOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      _onlineSearchQuery.isNotEmpty
                          ? 'No online orders match your search'
                          : 'No online orders found for this period',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            if (constraints.maxWidth < 900) {
              return _buildOnlineOrdersTabView(
                  preparingOrders, readyOrders, pickedUpOrders);
            }
            return _buildOnlineOrdersRowLayout(
                preparingOrders, readyOrders, pickedUpOrders);
          }),
        ),
      ],
    );
  }

  Widget _buildOnlineOrdersRowLayout(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: _buildOrderColumn(
                title: 'Preparing',
                orders: preparingOrders,
                status: 'preparing')),
        const SizedBox(width: 12),
        Expanded(
            child: _buildOrderColumn(
                title: 'Ready for Pickup',
                orders: readyOrders,
                status: 'ready')),
        const SizedBox(width: 12),
        Expanded(
            child: _buildOrderColumn(
                title: 'Picked Up',
                orders: pickedUpOrders,
                status: 'pickedup')),
      ]),
    );
  }

  Widget _buildOnlineOrdersTabView(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: 'Preparing (${preparingOrders.length})'),
              Tab(text: 'Ready (${readyOrders.length})'),
              Tab(text: 'Picked Up (${pickedUpOrders.length})'),
            ]),
        Expanded(
            child: TabBarView(children: [
          _buildOrderList(preparingOrders, isOnline: true),
          _buildOrderList(readyOrders, isOnline: true),
          _buildOrderList(pickedUpOrders, isOnline: true),
        ])),
      ]),
    );
  }

  Widget _buildOrderColumn(
      {required String title,
      required List<PendingOrder> orders,
      required String status}) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(orders.length.toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Expanded(child: _buildOrderList(orders, isOnline: true)),
      ]),
    );
  }

  Widget _buildOrderList(List<PendingOrder> orders, {required bool isOnline}) {
    if (orders.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('No orders in this category.',
            style: Theme.of(context).textTheme.bodyMedium),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return isOnline
            ? _buildOnlineOrderCard(order)
            : _buildCounterOrderCard(order);
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  Widget _buildOnlineOrderCard(PendingOrder order) {
    final status = order.status.toLowerCase();
    final isPreparing = status == 'open' || status == 'preparing';
    final isReady = status == 'ready';

    final timerDuration = isReady && order.readyAt != null
        ? DateTime.now().difference(DateTime.parse(order.readyAt!))
        : DateTime.now().difference(DateTime.parse(order.createdAt));

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Text('#${order.orderId} - ${order.customerName}',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            _buildTag('Online', theme.colorScheme.primary),
          ]),
          const SizedBox(height: 8),
          Text('Ph: ${order.customerMobile}',
              style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const Divider(height: 20),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(children: [
                  Text('${item.quantity}x',
                      style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.name, style: textTheme.bodyMedium)),
                ]),
              )),
          const Divider(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              // Stack vertically if space is limited
              if (constraints.maxWidth < 250) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total',
                                style: textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6))),
                            Text('₹${order.totalPrice.toStringAsFixed(2)}',
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (isPreparing || isReady)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Icon(Icons.timer_outlined,
                                  size: 18, color: _getStatusColor(status)),
                              const SizedBox(width: 6),
                              Text(_formatDuration(timerDuration),
                                  style: textTheme.titleMedium?.copyWith(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8)),
                            ]),
                          ),
                      ],
                    ),
                    if (order.paymentMethod.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        _buildTag(order.paymentMethod, Colors.grey,
                            isOutlined: true)
                      ])
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildActionButtons(order, isOnline: true),
                      ),
                    ),
                  ],
                );
              }
              // Horizontal layout for larger screens
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total',
                              style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                          Text('₹${order.totalPrice.toStringAsFixed(2)}',
                              style: textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (isPreparing || isReady)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(Icons.timer_outlined,
                                size: 18, color: _getStatusColor(status)),
                            const SizedBox(width: 6),
                            Text(_formatDuration(timerDuration),
                                style: textTheme.titleMedium?.copyWith(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ]),
                        ),
                    ],
                  ),
                  if (order.paymentMethod.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      _buildTag(order.paymentMethod, Colors.grey,
                          isOutlined: true)
                    ])
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildActionButtons(order, isOnline: true),
                  ),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildActionButtons(PendingOrder order, {bool isOnline = true}) {
    final status = order.status.toLowerCase();
    final List<Widget> buttons = [];

    if (isOnline) {
      if (status == 'open') {
        buttons.add(
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            onPressed: () => _markOrderReady(order.id),
            label: const Text('Mark Ready',
                overflow: TextOverflow.ellipsis, maxLines: 1),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        );
      } else if (status == 'ready') {
        buttons.add(
          ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            onPressed: () => _markOrderPickedUp(order.id),
            label: const Text('Mark Picked Up',
                overflow: TextOverflow.ellipsis, maxLines: 1),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        );
      }
    }

    if (status != 'open') {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 6));
      }
      buttons.add(
        TextButton(
          onPressed: () => _viewInvoice(order),
          child: const Text('Invoice',
              overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      );
    }
    return buttons;
  }

  Widget _buildCounterOrdersView(List<PendingOrder> counterOrders) {
    return Column(
      children: [
        // Search Bar and Date Filter
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _counterSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by order ID, name, phone, or item...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _counterSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _counterSearchController.clear();
                            // Manually trigger the listener logic
                            _onCounterSearchChanged();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Date Filter
              Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<String>(
                      // Popup now calls setState
                      onSelected: (value) {
                        if (value == 'custom') {
                          _showCounterCustomDatePicker();
                        } else {
                          setState(() {
                            _counterSelectedFilter = value;
                            _applyCounterFilter();
                          });
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'today', child: Text('Today')),
                        const PopupMenuItem(
                            value: 'this_week', child: Text('This Week')),
                        const PopupMenuItem(
                            value: 'this_month', child: Text('This Month')),
                        const PopupMenuItem(
                            value: 'this_year', child: Text('This Year')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'custom', child: Text('Custom Range')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(_getCounterFilterDisplayText()),
                              ],
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Orders List
        Expanded(
          child: counterOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        _counterSearchQuery.isNotEmpty
                            ? 'No orders match your search'
                            : 'No counter orders found for this period',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _buildOrderList(counterOrders, isOnline: false),
        ),
      ],
    );
  }

  Widget _buildCounterOrderCard(PendingOrder order) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Order #${order.orderId}',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            _buildTag('Counter', Colors.deepOrange.shade400),
          ]),
          if (order.customerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(order.customerName,
                style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ],
          const Divider(height: 20),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(children: [
                  Text('${item.quantity}x',
                      style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.name, style: textTheme.bodyMedium)),
                  Text('₹${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: textTheme.bodyMedium),
                ]),
              )),
          const Divider(height: 20),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total',
                      style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text('₹${order.totalPrice.toStringAsFixed(2)}',
                      style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor('ready'))),
                ]),
                TextButton(
                    onPressed: () => _viewInvoice(order),
                    child: const Text('View Invoice'))
              ]),
        ]),
      ),
    );
  }

  Widget _buildTag(String text, Color color, {bool isOutlined = false}) {
    final theme = Theme.of(context);
    if (isOutlined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor, width: 1.5)),
        child: Text(text,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: theme.textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600, color: color)),
    );
  }
}
