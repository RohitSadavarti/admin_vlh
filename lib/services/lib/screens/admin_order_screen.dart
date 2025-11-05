// lib/screens/admin_order_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/order_details.dart';
import '../models/pending_order.dart';
import '../screens/invoice_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

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

  // Separate lists for all and filtered orders
  List<PendingOrder> _allOnlineOrders = [];
  List<PendingOrder> _allCounterOrders = [];
  List<PendingOrder> _filteredOnlineOrders = [];
  List<PendingOrder> _filteredCounterOrders = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'this_year';
  DateTimeRange? _customDateRange;

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
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
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

      setState(() {
        _allOnlineOrders = allOrders
            .where((o) => o.orderPlacedBy?.toLowerCase() == 'customer')
            .toList();
        _allCounterOrders = allOrders
            .where((o) => o.orderPlacedBy?.toLowerCase() == 'counter')
            .toList();
        _applyFilters(); // Apply initial filter to both online and counter orders
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // This function now filters both online and counter orders
  void _applyFilters() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedFilter) {
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
        if (_customDateRange != null) {
          startDate = _customDateRange!.start;
          endDate = _customDateRange!.end.add(const Duration(days: 1));
        } else {
          _filteredOnlineOrders =
              _allOnlineOrders; // Default to all if no range
          _filteredCounterOrders = _allCounterOrders;
          setState(() {});
          return;
        }
        break;
      default:
        _filteredOnlineOrders = _allOnlineOrders; // Default to all
        _filteredCounterOrders = _allCounterOrders;
        setState(() {});
        return;
    }

    setState(() {
      _filteredOnlineOrders = _allOnlineOrders.where((order) {
        try {
          final orderDate = DateTime.parse(order.createdAt);
          return !orderDate.isBefore(startDate) && orderDate.isBefore(endDate);
        } catch (e) {
          return false; // Don't include if date parsing fails
        }
      }).toList();
      _filteredCounterOrders = _allCounterOrders.where((order) {
        try {
          final orderDate = DateTime.parse(order.createdAt);
          return !orderDate.isBefore(startDate) && orderDate.isBefore(endDate);
        } catch (e) {
          return false; // Don't include if date parsing fails
        }
      }).toList();
    });
  }

  Future<void> _onOrderAction(int orderDbId, String action) async {
    try {
      final success = await _apiService.updateOrderStatus(orderDbId, action);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order status updated successfully'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ));

      if (success['success']) {
        await _loadOrders();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error));
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

  String _getFilterDisplayText() {
    switch (_selectedFilter) {
      case 'today':
        return 'Today';
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return 'This Month';
      case 'this_year':
        return 'This Year';
      case 'custom':
        if (_customDateRange != null) {
          final formatter = DateFormat('MMM dd');
          return '${formatter.format(_customDateRange!.start)} - ${formatter.format(_customDateRange!.end)}';
        }
        return 'Custom Range';
      default:
        return 'This Month';
    }
  }

  void _showCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 'custom';
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preparingOrders = _filteredOnlineOrders
        .where((o) =>
            o.status.toLowerCase() == 'open' ||
            o.status.toLowerCase() == 'preparing')
        .toList();
    final readyOrders = _filteredOnlineOrders
        .where((o) => o.status.toLowerCase() == 'ready')
        .toList();
    final pickedUpOrders = _filteredOnlineOrders
        .where((o) =>
            o.status.toLowerCase() == 'pickedup' ||
            o.status.toLowerCase() == 'completed')
        .toList();

    final onlineOrderCount = preparingOrders.length + readyOrders.length;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('Order Management'),
            pinned: true,
            floating: true,
            forceElevated: innerBoxIsScrolled,
            actions: [
              _buildDateFilter(),
              IconButton(
                  onPressed: _loadOrders,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Orders'),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.7),
              tabs: [
                Tab(child: Text('Online Orders ($onlineOrderCount)')),
                Tab(
                    child: Text(
                        'Counter Orders (${_filteredCounterOrders.length})')),
              ],
            ),
          )
        ],
        body: _buildBody(preparingOrders, readyOrders, pickedUpOrders,
            _filteredCounterOrders),
      ),
    );
  }

  Widget _buildDateFilter() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'custom') {
          _showCustomDatePicker();
        } else {
          setState(() {
            _selectedFilter = value;
            _applyFilters();
          });
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'today', child: Text('Today')),
        const PopupMenuItem(value: 'this_week', child: Text('This Week')),
        const PopupMenuItem(value: 'this_month', child: Text('This Month')),
        const PopupMenuItem(value: 'this_year', child: Text('This Year')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'custom', child: Text('Custom Range')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 6),
            Text(_getFilterDisplayText(),
                style: Theme.of(context).textTheme.bodyMedium),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders,
      List<PendingOrder> pickedUpOrders,
      List<PendingOrder> counterOrders) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load orders',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
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
        child: _buildCounterOrdersView(counterOrders),
      ),
    ]);
  }

  Widget _buildOnlineOrdersView(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900)
        return _buildOnlineOrdersTabView(
            preparingOrders, readyOrders, pickedUpOrders);
      return _buildOnlineOrdersRowLayout(
          preparingOrders, readyOrders, pickedUpOrders);
    });
  }

  Widget _buildOnlineOrdersRowLayout(List<PendingOrder> preparingOrders,
      List<PendingOrder> readyOrders, List<PendingOrder> pickedUpOrders) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
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
                title: 'Completed',
                orders: pickedUpOrders,
                status: 'completed')),
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
              Tab(text: 'Completed (${pickedUpOrders.length})'),
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
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total',
                      style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text('₹${order.totalPrice.toStringAsFixed(2)}',
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ]),
                if (isPreparing || isReady)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  )
              ]),
          if (order.paymentMethod.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              _buildTag(order.paymentMethod, Colors.grey, isOutlined: true)
            ])
          ],
          const SizedBox(height: 12),
          Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(order, isOnline: true)),
        ]),
      ),
    );
  }

  List<Widget> _buildActionButtons(PendingOrder order, {bool isOnline = true}) {
    final status = order.status.toLowerCase();
    final List<Widget> buttons = [];

    if (isOnline) {
      if (status == 'open' || status == 'preparing') {
        buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _onOrderAction(order.id, 'ready'),
            label: const Text('Mark Ready')));
      } else if (status == 'ready') {
        buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () => _onOrderAction(order.id, 'pickedup'),
            label: const Text('Mark Picked Up')));
      }
    }

    if (status != 'open' && status != 'preparing') {
      buttons.add(const SizedBox(width: 8));
      buttons.add(TextButton(
          onPressed: () => _viewInvoice(order), child: const Text('Invoice')));
    }
    return buttons;
  }

  Widget _buildCounterOrdersView(List<PendingOrder> counterOrders) {
    if (counterOrders.isEmpty)
      return const Center(
          child: Text('No counter orders to show.',
              style: TextStyle(color: Colors.grey)));
    return _buildOrderList(counterOrders, isOnline: false);
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
                if (_buildActionButtons(order, isOnline: false).isNotEmpty)
                  Row(children: _buildActionButtons(order, isOnline: false))
                else
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
