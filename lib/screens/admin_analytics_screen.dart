// lib/screens/admin_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/analytics_data.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_app_bar.dart'; // Import ProfileAppBar

// --- HELPER CLASSES FOR SYNCFUSION CHARTS ---
class _MostOrderedData {
  _MostOrderedData(this.item, this.count);
  final String item;
  final double count;
}

class _RevenueOrdersData {
  _RevenueOrdersData(this.day, this.revenue, this.orders);
  final String day;
  final double revenue;
  final double orders;
}

class _Top5ItemData {
  _Top5ItemData(this.day, this.count);
  final String day;
  final double count;
}

class _OrdersByHourData {
  _OrdersByHourData(this.hour, this.count);
  final String hour;
  final double count;
}

class _PieChartData {
  _PieChartData(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}
// --- END HELPER CLASSES ---

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Future<AnalyticsData>? _analyticsData;
  String _selectedFilter = 'this_month';
  DateTimeRange? _customDateRange;
  String _paymentFilter =
      'Total'; // Changed back to 'Total' to match backend expectations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late TooltipBehavior _revenueTooltipBehavior;
  late TooltipBehavior _mostOrderedTooltipBehavior;
  late TooltipBehavior _top5TooltipBehavior;
  late TooltipBehavior _ordersByHourTooltipBehavior;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _revenueTooltipBehavior = TooltipBehavior(enable: true);
    _mostOrderedTooltipBehavior = TooltipBehavior(enable: true);
    _top5TooltipBehavior = TooltipBehavior(enable: true);
    _ordersByHourTooltipBehavior = TooltipBehavior(enable: true);

    _loadAnalyticsData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadAnalyticsData() {
    setState(() {
      if (_selectedFilter == 'custom' && _customDateRange != null) {
        final startDate = _customDateRange!.start.toString().split(' ')[0];
        final endDate = _customDateRange!.end.toString().split(' ')[0];

        _analyticsData = _apiService.getAnalyticsData(
          dateFilter: _selectedFilter,
          paymentFilter: _paymentFilter,
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        _analyticsData = _apiService.getAnalyticsData(
          dateFilter: _selectedFilter,
          paymentFilter: _paymentFilter,
        );
      }
    });
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: ProfileAppBar(
        title: 'Analytics Dashboard', // Changed from Text('...') to String
        onRefresh: _loadAnalyticsData,
        //actions: [
        //  _buildDateFilter(isDark),
        //  _buildPaymentFilter(isDark),
        //  const SizedBox(width: 8),
        //],
      ),
      body: FutureBuilder<AnalyticsData>(
        future: _analyticsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading analytics...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading analytics',
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadAnalyticsData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No analytics data available.'));
          }

          final data = snapshot.data!;
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateFilter(isDark),
                  const SizedBox(height: 16),
                  _buildPaymentFilter(isDark),
                  const SizedBox(height: 32),
                  _buildKeyMetricsSection(data.keyMetrics, isDark),
                  const SizedBox(height: 32),
                  _buildChartsSection(data, isDark),
                  const SizedBox(height: 32),
                  _buildRecentOrdersTable(data.tableData, isDark),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex:
            1, // changed currentIndex from 2 to 1 so Analytics icon highlights correctly
        onTap: (index) {},
      ),
    );
  }

  Widget _buildDateFilter(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            _selectedFilter = value;
            if (value == 'custom') {
              _showCustomDatePicker();
            } else {
              _customDateRange = null;
              _loadAnalyticsData();
            }
          });
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                _getFilterDisplayText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentFilter(bool isDark) {
    return FittedBox(
      // Wrap with FittedBox to prevent overflow on small screens
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ToggleButtons(
          isSelected: [
            _paymentFilter == 'Total',
            _paymentFilter == 'Cash',
            _paymentFilter == 'Online'
          ],
          onPressed: (index) {
            setState(() {
              _paymentFilter = ['Total', 'Cash', 'Online'][index];
              _loadAnalyticsData();
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('All'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Cash'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Online'),
            ),
          ],
        ),
      ),
    ); // <-- This is the correct closing parenthesis for FittedBox
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
        _loadAnalyticsData();
      });
    }
  }

  Widget _buildKeyMetricsSection(KeyMetrics metrics, bool isDark) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style:
              textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final items = [
              _buildMetricCard(
                'Total Revenue',
                '₹${_formatNumber(metrics.totalRevenue)}',
                Icons.account_balance_wallet_rounded,
                Theme.of(context).colorScheme.secondary,
                '+12.5%',
                isDark,
              ),
              _buildMetricCard(
                'Total Orders',
                _formatNumber(metrics.totalOrders.toDouble()),
                Icons.shopping_bag_rounded,
                Theme.of(context).colorScheme.primary,
                '+8.2%',
                isDark,
              ),
              _buildMetricCard(
                'Avg Order Value',
                '₹${_formatNumber(metrics.averageOrderValue)}',
                Icons.trending_up_rounded,
                Colors.amber.shade700,
                '+5.1%',
                isDark,
              ),
            ];

            if (isWide) {
              return Row(
                children: items
                    .map((item) => Expanded(child: item))
                    .expand((widget) => [widget, const SizedBox(width: 16)])
                    .toList()
                  ..removeLast(),
              );
            } else {
              return Column(
                children: items
                    .expand((widget) => [widget, const SizedBox(height: 16)])
                    .toList()
                  ..removeLast(),
              );
            }
          },
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
    bool isDark,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 12,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        change,
                        style: textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(AnalyticsData data, bool isDark) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Analytics',
          style:
              textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          'Revenue & Orders Trend',
          _buildRevenueOrdersBarChart(data.dayWiseRevenue, isDark),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final children = [
              _buildChartCard(
                'Most Ordered Items',
                _buildMostOrderedBarChart(data.mostOrderedItems, isDark),
              ),
              _buildChartCard(
                'Orders by Hour',
                _buildOrdersByHourChart(data.ordersByHour, isDark),
              ),
              _buildChartCard(
                'Payment Methods',
                _buildPieChart(data.paymentMethodDistribution, isDark),
              ),
            ];
            final top5 = _buildChartCard(
              'Day-wise Top 5 Items',
              _buildTop5StackedBarChart(data.dayWiseMenu, isDark),
            );

            if (isWide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 20),
                      Expanded(child: children[1]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[2]),
                      const SizedBox(width: 20),
                      Expanded(child: top5),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: (children + [top5])
                    .expand((w) => [w, const SizedBox(height: 20)])
                    .toList()
                  ..removeLast(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(height: 320, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildMostOrderedBarChart(ChartData chartData, bool isDark) {
    final axisColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final List<_MostOrderedData> chartDataList = List.generate(
      chartData.labels.length,
      (i) => _MostOrderedData(chartData.labels[i], chartData.data[i]),
    );

    final maxValue = chartDataList.isEmpty
        ? 10.0
        : chartDataList.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return SfCartesianChart(
      isTransposed: true,
      legend: Legend(isVisible: false),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelIntersectAction: AxisLabelIntersectAction.wrap,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      primaryYAxis: NumericAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
        maximum: maxValue * 1.25,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        BarSeries<_MostOrderedData, String>(
          name: 'Orders',
          dataSource: chartDataList,
          xValueMapper: (_MostOrderedData data, _) => data.item,
          yValueMapper: (_MostOrderedData data, _) => data.count,
          color: Theme.of(context).colorScheme.primary,
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(6)),
          width: 0.5,
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.inside,
            labelAlignment: ChartDataLabelAlignment.middle,
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(ChartData chartData, bool isDark) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Colors.amber.shade600,
      Colors.red.shade500,
    ];

    if (chartData.data.isEmpty) {
      return Center(
          child: Text('No data', style: Theme.of(context).textTheme.bodySmall));
    }

    final total = chartData.data.reduce((a, b) => a + b);

    final pieData = chartData.data.asMap().entries.map((e) {
      final i = e.key;
      final v = e.value;
      return _PieChartData(chartData.labels[i], v, colors[i % colors.length]);
    }).toList();

    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        PieSeries<_PieChartData, String>(
          dataSource: pieData,
          xValueMapper: (_PieChartData data, _) => data.label,
          yValueMapper: (_PieChartData data, _) => data.value,
          pointColorMapper: (_PieChartData data, _) => data.color,
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            labelIntersectAction: LabelIntersectAction.shift,
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final pct =
                  total > 0 ? ((data as _PieChartData).value / total) * 100 : 0;
              return Text(
                '${pct.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersByHourChart(ChartData chartData, bool isDark) {
    final axisColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final List<_OrdersByHourData> chartDataList = List.generate(
        chartData.labels.length,
        (i) => _OrdersByHourData(chartData.labels[i], chartData.data[i]));

    final maxValue = chartDataList.isEmpty
        ? 10.0
        : chartDataList.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return SfCartesianChart(
      legend: Legend(isVisible: false),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
        interval: 3,
      ),
      primaryYAxis: NumericAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
        maximum: maxValue * 1.4,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        SplineAreaSeries<_OrdersByHourData, String>(
          name: 'Orders',
          dataSource: chartDataList,
          xValueMapper: (_OrdersByHourData data, _) => data.hour,
          yValueMapper: (_OrdersByHourData data, _) => data.count,
          borderColor: Theme.of(context).colorScheme.primary,
          borderWidth: 3,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.4),
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 4,
            width: 4,
            borderColor: Theme.of(context).colorScheme.primary,
            color: Theme.of(context).colorScheme.surface,
            borderWidth: 2,
          ),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(color: axisColor, fontSize: 10),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final count = (data as _OrdersByHourData).count;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  count.toStringAsFixed(0),
                  style: TextStyle(color: axisColor, fontSize: 10),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueOrdersBarChart(DayWiseRevenue data, bool isDark) {
    final axisColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final List<_RevenueOrdersData> chartDataList = List.generate(
      data.labels.length,
      (i) => _RevenueOrdersData(
          data.labels[i], data.revenueData[i], data.ordersData[i]),
    );

    return SfCartesianChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(color: axisColor),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: 'Revenue (₹)',
          textStyle: TextStyle(color: axisColor, fontSize: 12),
        ),
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'ordersAxis',
          opposedPosition: true,
          title: AxisTitle(
            text: 'Number of Orders',
            textStyle: TextStyle(color: axisColor, fontSize: 12),
          ),
          labelStyle: TextStyle(color: axisColor, fontSize: 11),
          majorGridLines: const MajorGridLines(width: 0),
        )
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<_RevenueOrdersData, String>(
          name: 'Revenue (₹)',
          dataSource: chartDataList,
          xValueMapper: (_RevenueOrdersData data, _) => data.day,
          yValueMapper: (_RevenueOrdersData data, _) => data.revenue,
          color: Theme.of(context).colorScheme.primary,
          width: 0.8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final revenue = (data as _RevenueOrdersData).revenue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  _formatNumber(revenue),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ),
        LineSeries<_RevenueOrdersData, String>(
          name: 'Orders',
          dataSource: chartDataList,
          xValueMapper: (_RevenueOrdersData data, _) => data.day,
          yValueMapper: (_RevenueOrdersData data, _) => data.orders,
          yAxisName: 'ordersAxis',
          color: Theme.of(context).colorScheme.secondary,
          width: 3,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final orders = (data as _RevenueOrdersData).orders;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  orders.toStringAsFixed(0),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTop5StackedBarChart(DayWiseMenu data, bool isDark) {
    final axisColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final List<Color> colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Colors.amber.shade600,
      Colors.red.shade500,
      Colors.purple.shade400,
    ];

    final sortedDatasets = data.datasets
        .map((ds) => {
              'dataset': ds,
              'total': ds.data.isEmpty ? 0.0 : ds.data.reduce((a, b) => a + b),
            })
        .toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    final top5Datasets =
        sortedDatasets.take(5).map((e) => e['dataset'] as MenuDataset).toList();

    List<StackedColumnSeries<_Top5ItemData, String>> seriesList = [];

    for (int i = 0; i < top5Datasets.length; i++) {
      final dataset = top5Datasets[i];
      final List<_Top5ItemData> itemDataList = List.generate(
        data.labels.length,
        (dayIndex) => _Top5ItemData(data.labels[dayIndex],
            dayIndex < dataset.data.length ? dataset.data[dayIndex] : 0.0),
      );

      seriesList.add(
        StackedColumnSeries<_Top5ItemData, String>(
          name: dataset.label,
          dataSource: itemDataList,
          xValueMapper: (_Top5ItemData data, _) => data.day,
          yValueMapper: (_Top5ItemData data, _) => data.count,
          color: colors[i % colors.length],
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.inside,
            labelAlignment: ChartDataLabelAlignment.middle,
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final double count = (data as _Top5ItemData).count;
              if (count == 0) {
                return const SizedBox.shrink();
              }
              return Text(
                count.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      );
    }

    return SfCartesianChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(color: axisColor),
        itemPadding: 20,
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        labelStyle: TextStyle(color: axisColor, fontSize: 11),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: seriesList,
    );
  }

  Widget _buildRecentOrdersTable(List<TableOrder> orders, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Orders',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/admin-orders');
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Items')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Status')),
              ],
              rows: orders.take(10).map((order) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('MMM dd, yyyy')
                            .format(DateTime.parse(order.createdAt)),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Text(
                        '#${order.orderId}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          order.itemsText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '₹${order.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.paymentMethod,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.orderStatus)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.orderStatus,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _getStatusColor(order.orderStatus),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pickedup':
      case 'completed':
        return Theme.of(context).colorScheme.secondary;
      case 'ready':
        return Theme.of(context).colorScheme.primary;
      case 'open':
      case 'preparing':
        return Colors.amber.shade700;
      case 'pending':
        return Colors.orange.shade600;
      case 'cancelled':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.grey.shade600;
    }
  }
}
