// lib/screens/admin_analytics_screen_fixed.dart
// Clean, minimal admin analytics screen (safe replacement for review).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/analytics_data.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class AdminAnalyticsScreenFixed extends StatefulWidget {
  const AdminAnalyticsScreenFixed({super.key});

  @override
  State<AdminAnalyticsScreenFixed> createState() =>
      _AdminAnalyticsScreenFixedState();
}

class _AdminAnalyticsScreenFixedState extends State<AdminAnalyticsScreenFixed>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService.instance;
  Future<AnalyticsData>? _analyticsData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadAnalyticsData() {
    setState(() {
      _analyticsData = _apiService.getAnalyticsData('this_month');
    });
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics (fixed preview)')),
      drawer: const AppDrawer(),
      body: FutureBuilder<AnalyticsData>(
        future: _analyticsData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: Text('No data'));

          final data = snapshot.data!;
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartCard('Most Ordered Items',
                        _buildBarChart(data.mostOrderedItems, isDark), isDark),
                    const SizedBox(height: 20),
                    _buildChartCard(
                        'Payment Methods',
                        _buildPieChart(data.paymentMethodDistribution, isDark),
                        isDark),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart, bool isDark) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(height: 300, child: chart)
        ]),
      );

  Widget _buildBarChart(ChartData chartData, bool isDark) {
    final maxValue = chartData.data.isNotEmpty
        ? chartData.data.reduce((a, b) => a > b ? a : b)
        : 10.0;
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444)
    ];

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxValue * 1.2,
      barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(0.75),
              tooltipRoundedRadius: 8,
              getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  '${chartData.labels[gi]}\n${r.toY.toStringAsFixed(0)} orders',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)))),
      titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= chartData.labels.length)
                      return const Text('');
                    return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(chartData.labels[i],
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 11)));
                  },
                  reservedSize: 32)),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Text(val.toInt().toString(),
                      style: TextStyle(
                          color:
                              isDark ? Colors.white54 : Colors.grey.shade600)),
                  reservedSize: 36))),
      gridData: FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(
          show: true,
          border: Border(
              bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade300),
              left: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade300))),
      barGroups: chartData.data.asMap().entries.map((e) {
        final i = e.key;
        final v = e.value;
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
              toY: v,
              color: colors[i % colors.length],
              width: 26,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)))
        ]);
      }).toList(),
      extraLinesData: ExtraLinesData(
          horizontalLines: chartData.data.asMap().entries.map((e) {
        final idx = e.key;
        final val = e.value;
        return HorizontalLine(
            y: val,
            color: Colors.transparent,
            label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.only(left: idx * 50.0, bottom: 6),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                labelResolver: (l) => val.toStringAsFixed(0)));
      }).toList()),
    ));
  }

  Widget _buildPieChart(ChartData chartData, bool isDark) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444)
    ];
    final total = chartData.data.isNotEmpty
        ? chartData.data.reduce((a, b) => a + b)
        : 1.0;
    return Column(children: [
      Expanded(
          child: PieChart(PieChartData(
              sections: chartData.data.asMap().entries.map((e) {
                final i = e.key;
                final v = e.value;
                final pct = total > 0 ? (v / total) * 100 : 0;
                return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: v,
                    title: '${pct.toStringAsFixed(1)}%',
                    radius: 70,
                    titleStyle: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600));
              }).toList(),
              sectionsSpace: 4,
              centerSpaceRadius: 36))),
      const SizedBox(height: 12),
      Wrap(
          spacing: 12,
          children: chartData.labels.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final v = chartData.data[i];
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('$label (${v.toStringAsFixed(0)})',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 12))
            ]);
          }).toList()),
    ]);
  }
}
