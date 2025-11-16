// lib/screens/admin_dashboard_screen.dart
import 'dart:async'; // <-- MODIFICATION: Added for StreamSubscription

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_data.dart'; // <-- MODIFICATION: Added import for TableOrder
import '../services/api_service.dart';
import '../services/order_update_service.dart'; // <-- MODIFICATION: Added
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_app_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  Future<AnalyticsData>? _analyticsDataFuture;

  // <-- MODIFICATION: Added subscription variable
  late StreamSubscription _orderUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();

    // <-- MODIFICATION: Start listening for order updates
    _orderUpdateSubscription = OrderUpdateService().stream.listen((_) {
      print("Refreshing AdminDashboardScreen due to order update...");
      if (mounted) {
        _loadData();
      }
    });
  }

  // <-- MODIFICATION: Added dispose method
  @override
  void dispose() {
    _orderUpdateSubscription.cancel();
    super.dispose();
  }

  // <-- MODIFICATION: Changed to 'Future<void>' and added 'async'
  Future<void> _loadData() async {
    setState(() {
      _analyticsDataFuture = _apiService.getAnalyticsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: ProfileAppBar(
        title: 'Dashboard',
        onRefresh: _loadData,
      ),
      body: FutureBuilder<AnalyticsData>(
        future: _analyticsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load dashboard data.\nPlease check your connection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data found.'));
          }

          final data = snapshot.data!;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return RefreshIndicator(
            onRefresh:
                _loadData, // <-- This now correctly matches the function type
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildKeyMetricsSection(data.keyMetrics, isDark),
                  const SizedBox(height: 32),
                  // _buildChartsSection(data, isDark), // Placeholder
                  // const SizedBox(height: 32),
                  _buildRecentOrdersTable(data.tableData, isDark),
                  const SizedBox(height: 60), // Add padding for bottom nav
                ],
              ),
            ),
          );
        },
      ),
      // <-- MODIFICATION: Added missing 'onTap' and fixed 'currentIndex'
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2, // Dashboard is index 2
        onTap: (index) {
          // Handle navigation if needed, or leave empty
        },
      ),
    );
  }

  Widget _buildKeyMetricsSection(KeyMetrics metrics, bool isDark) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final List<Map<String, dynamic>> dashboardItems = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'title': 'Total Revenue',
        'value': '₹${NumberFormat.compact().format(metrics.totalRevenue)}',
        'color': theme.colorScheme.secondary,
        'route': '/admin-analytics',
      },
      {
        'icon': Icons.shopping_bag_rounded,
        'title': 'Total Orders',
        'value': metrics.totalOrders.toString(),
        'color': theme.colorScheme.primary,
        'route': '/admin-orders',
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Avg. Order Value',
        'value': '₹${NumberFormat.compact().format(metrics.averageOrderValue)}',
        'color': Colors.amber.shade700,
        'route': '/admin-analytics',
      },
      {
        'icon': Icons.receipt_long_rounded,
        'title': 'Take New Order',
        'value': 'POS',
        'color': Colors.deepPurple.shade400,
        'route': '/take-order',
      },
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dashboardItems.length,
      itemBuilder: (context, index) {
        final item = dashboardItems[index];
        return _buildStatCard(
          context: context,
          title: item['title'],
          value: item['value'],
          icon: item['icon'],
          color: item['color'],
          theme: theme,
          onTap: () {
            if (ModalRoute.of(context)?.settings.name != item['route']) {
              Navigator.pushNamed(context, item['route']);
            }
          },
        );
      },
    );
  }

  Widget _buildChartsSection(AnalyticsData data, bool isDark) {
    // This is a placeholder as the implementation wasn't in the provided file
    return Container(
      child: const Text('Charts Section'),
    );
  }

  // <-- MODIFICATION: Changed 'OrderData' to 'TableOrder'
  Widget _buildRecentOrdersTable(List<TableOrder> orders, bool isDark) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Orders',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Items')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Status')),
              ],
              rows: orders.take(5).map((order) {
                // Show 5 recent orders
                return DataRow(
                  cells: [
                    DataCell(Text(order.orderId)),
                    DataCell(SizedBox(
                      width: 150, // Give items column more space
                      child: Text(
                        order.itemsText,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    DataCell(Text('₹${order.totalPrice.toStringAsFixed(0)}')),
                    DataCell(Text(order.orderStatus)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      color: theme.cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 44, // Slightly smaller icon background
                height: 44,
                padding: const EdgeInsets.all(10), // Adjusted padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12), // Rounded corners
                ),
                child: Icon(icon, size: 24, color: color), // Adjusted size
              ),
              const SizedBox(width: 12), // Reduced spacing
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            // Smaller title
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            // Adjusted from headlineSmall
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
