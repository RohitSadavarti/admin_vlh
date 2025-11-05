// lib/screens/admin_dashboard_screen.dart - IMPROVED VERSION
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_data.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService.instance;
  Future<AnalyticsData>? _analyticsDataFuture;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Add delay and error handling
    _analyticsDataFuture = _apiService
        .getAnalyticsData('this_month')
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timed out. Please check your internet connection.');
          },
        )
        .then((data) {
          print('✅ Analytics data loaded successfully');
          setState(() => _isLoading = false);
          return data;
        })
        .catchError((error) {
          print('❌ Error loading analytics: $error');
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });
          throw error;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load dashboard',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<AnalyticsData>(
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available.'));
        }

        final data = snapshot.data!;
        final metrics = data.keyMetrics;

        return _buildDashboardGrid(context, metrics);
      },
    );
  }

  Widget _buildDashboardGrid(BuildContext context, KeyMetrics metrics) {
    final theme = Theme.of(context);
    final numberFormatter = NumberFormat.compact(locale: 'en_IN');

    final List<Map<String, dynamic>> dashboardItems = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'title': 'Total Revenue',
        'value': '₹${numberFormatter.format(metrics.totalRevenue)}',
        'color': theme.colorScheme.secondary,
        'route': '/admin-analytics',
      },
      {
        'icon': Icons.shopping_bag_rounded,
        'title': 'Total Orders',
        'value': numberFormatter.format(metrics.totalOrders),
        'color': theme.colorScheme.primary,
        'route': '/admin-orders',
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Avg. Order Value',
        'value': '₹${numberFormatter.format(metrics.averageOrderValue)}',
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
      {
        'icon': Icons.bar_chart_rounded,
        'title': 'View Analytics',
        'value': 'Deep Dive',
        'color': Colors.teal.shade400,
        'route': '/admin-analytics',
      },
      {
        'icon': Icons.list_alt_rounded,
        'title': 'Manage Orders',
        'value': 'All',
        'color': Colors.pink.shade400,
        'route': '/admin-orders',
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1100
          ? 3
          : constraints.maxWidth > 700
              ? 2
              : 1;
      final childAspectRatio = crossAxisCount == 1 ? 4.0 : 2.0;

      return RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: dashboardItems.length,
          itemBuilder: (context, index) {
            final item = dashboardItems[index];
            return _buildDashboardItem(
              context,
              icon: item['icon'],
              title: item['title'],
              value: item['value'],
              color: item['color'],
              onTap: () {
                Navigator.pushNamed(context, item['route']);
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildDashboardItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
